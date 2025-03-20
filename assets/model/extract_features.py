import librosa
import numpy as np
import sys
import json
import os
import matplotlib.pyplot as plt
import pandas as pd
# from librosa import effects
from scipy import stats
from scipy.signal import butter, filtfilt
import pywt
# from antropy import sample_entropy

def butter_bandpass(lowcut, highcut, fs, order=5):
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    b, a = butter(order, [low, high], btype='band')
    return b, a

def load_segmentation_data(tsv_file):
    """Load segmentation data from TSV file"""
    try:
        # Assuming columns are: start_time, end_time, segment_class
        segments = pd.read_csv(tsv_file, sep='\t', header=None)
        segments.columns = ['start_time', 'end_time', 'segment_class']
        return segments
    except Exception as e:
        print(f"Error loading segmentation data: {str(e)}")
        return None

def preprocess_heart_sound(file_path):
    """Preprocess heart sound recording with noise removal and segmentation"""
    try:
        y, sr = librosa.load(file_path, sr=None)

        # Add pre-emphasis before filtering
        y_preemph = librosa.effects.preemphasis(y, coef=0.97)  # coef from speech processing
        
        # Enhanced noise removal with bandpass filter (20-400 Hz)
        # Heart sounds typically concentrated in 20-200 Hz range
        b, a = butter_bandpass(20, 400, sr, order=4)  # Increased order for steeper roll-off
        y_filtered = filtfilt(b, a, y_preemph)  # Zero-phase filtering
        
        # Amplitude normalization
        y_normalized = librosa.util.normalize(y_filtered)
        
        # Envelope detection for improved onset detection
        # Get the amplitude envelope using Hilbert transform
        analytic_signal = librosa.effects.harmonic(y_normalized, margin=8.0)
        amplitude_envelope = np.abs(analytic_signal)
        
        # Smooth the envelope
        n_smooth = int(sr * 0.01)  # 10ms window
        if n_smooth % 2 == 0:
            n_smooth += 1  # Make sure it's odd for filtfilt
        amplitude_envelope = filtfilt(np.ones(n_smooth)/n_smooth, 1, amplitude_envelope)
        
        # Compute onset strength using the envelope
        hop_length = 256  # Reduced hop length for better time resolution
        onset_env = librosa.onset.onset_strength(
            y=amplitude_envelope, 
            sr=sr, 
            hop_length=hop_length,
            aggregate=np.mean,  
            fmax=500  # Focus on heart sound frequency range
        )
        
        # Define adaptive peak detection function
        def adaptive_peak_detection(onset_env, sr, hop_length):
            # Estimate noise floor
            noise_floor = float(np.percentile(onset_env, 15))
            # Dynamic threshold based on signal statistics
            threshold = float(noise_floor + 0.5 * (np.max(onset_env) - noise_floor))
            
            # Adapt wait time based on estimated heart rate
            # Using librosa's beat tracking as a rough heart rate estimate
            tempo, _ = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr, hop_length=hop_length)
            tempo = float(tempo)  # Convert to Python float
            # Ensure reasonable heart rate bounds (40-220 BPM)
            tempo = max(40, min(220, tempo)) if tempo > 0 else 80
            # Calculate minimum wait time (allowing for slightly faster detection than the estimated tempo)
            min_wait = float(60/(tempo*1.5) if tempo > 0 else 0.25)
            wait_frames = max(1, int(min_wait*sr/hop_length))
            
            # Dynamic window sizes based on estimated heart rate
            window_scale = float(80/tempo) if tempo > 0 else 1  # Scale windows for slower heart rates
            pre_max_frames = max(1, int(0.05*window_scale*sr/hop_length))
            post_max_frames = max(1, int(0.05*window_scale*sr/hop_length))
            pre_avg_frames = max(1, int(0.1*window_scale*sr/hop_length))
            post_avg_frames = max(1, int(0.1*window_scale*sr/hop_length))
            
            # Perform peak picking with adaptive parameters
            peaks = librosa.util.peak_pick(
                onset_env,
                pre_max=pre_max_frames,
                post_max=post_max_frames,
                pre_avg=pre_avg_frames,
                post_avg=post_avg_frames,
                delta=threshold,
                wait=wait_frames
            )
            
            # Log the adaptive parameters used
            print(f"Adaptive peak detection: tempo={tempo:.1f} BPM, threshold={threshold:.4f}, wait={min_wait:.3f}s")
            
            return peaks

        # Use adaptive peak detection
        peaks = adaptive_peak_detection(onset_env, sr, hop_length)

        # If too few peaks detected, fall back to the original method
        if len(peaks) < 4:  # Need at least 2 complete heart cycles
            print("Adaptive peak detection found too few peaks. Falling back to fixed parameters.")
            peaks = librosa.util.peak_pick(
                onset_env,
                pre_max=max(1, int(0.05*sr/hop_length)),
                post_max=max(1, int(0.05*sr/hop_length)),
                pre_avg=max(1, int(0.1*sr/hop_length)),
                post_avg=max(1, int(0.1*sr/hop_length)),
                delta=0.07,
                wait=max(1, int(0.25*sr/hop_length))
            )
        
        # Convert frame indices to sample indices
        peak_times = librosa.frames_to_time(peaks, sr=sr, hop_length=hop_length)
        peak_samples = (peak_times * sr).astype(int)
        
        # Segment into cardiac cycles with more reliable peak detection
        segments = []
        if len(peak_samples) >= 4:
            # Try to identify S1-S2 pairs using amplitude and spacing
            # S1 is typically louder than S2
            amplitudes = [np.max(y_normalized[max(0, p-int(0.05*sr)):min(len(y_normalized), p+int(0.05*sr))]) for p in peak_samples]
            
            # Group peaks into likely cardiac cycles
            for i in range(0, len(peak_samples)-3, 2):
                start_idx = peak_samples[i]
                # We want to capture a complete cardiac cycle S1-S2-S1
                end_idx = peak_samples[i+2]
                if end_idx > start_idx and end_idx < len(y_normalized):
                    segments.append(y_normalized[start_idx:end_idx])
        
        if segments:
            # Select the median length segment as representative
            segment_lengths = [len(s) for s in segments]
            median_idx = np.argsort(segment_lengths)[len(segment_lengths)//2]
            return segments[median_idx], sr, y_normalized, onset_env, peaks
        else:
            # Return full audio if segmentation failed
            print("Warning: Segmentation failed. Using full audio.")
            return y_normalized, sr, y_normalized, onset_env, peaks
            
    except Exception as e:
        print(f"Preprocessing error: {str(e)}")
        import traceback
        traceback.print_exc()
        return None, None, None, None, None
    
def select_optimal_features(features):
    """Select optimal feature set for heart sound classification"""
    
    # Essential timing features
    timing_features = {
        k: features[k] for k in [
            'HeartRate',
            'Systole_Mean', 'Systole_Std',
            'Diastole_Mean', 'Diastole_Std'
        ] if k in features
    }
    
    # Primary spectral features
    spectral_features = {
        k: features[k] for k in [
            'Q_Factor',
            'SpectralFlatness',
            'ZeroCrossingRate'
        ] if k in features
    }
    
    # Reduced MFCCs (first 13 only)
    mfcc_features = {
        k: features[k] for k in features.keys() 
        if 'MFCC_mean' in k and int(k.split('_')[-1]) <= 13
    }
    
    # Energy bands (all three are physiologically relevant)
    energy_features = {
        k: features[k] for k in features.keys()
        if 'Energy_' in k
    }
    
    # Select only the first 3 levels of wavelet features
    wavelet_features = {
        k: features[k] for k in features.keys()
        if ('Wavelet_' in k and 
            int(k.split('_')[1]) <= 2 and
            any(x in k for x in ['Energy', 'Shannon']))
    }
    
    return {
        **timing_features,
        **spectral_features,
        **mfcc_features,
        **energy_features,
        **wavelet_features
    }

def extract_features(file_path, segmentation_file=None):
    """Cardiac-specific feature extraction with preprocessing and validation"""
    try:
        if not os.path.exists(file_path):
            return {"error": f"File not found: {file_path}"}
            
        # Preprocess audio
        preprocessed_audio, sr, full_audio, onset_env, peaks = preprocess_heart_sound(file_path)
        if preprocessed_audio is None:
            return {"error": "Preprocessing failed"}, {}
        
        # Initialize features early to avoid undefined variable issues
        features = {}
        validation_info = {}
        
        # MFCCs
        mfccs = librosa.feature.mfcc(
        y=preprocessed_audio, 
        sr=sr, 
        n_mfcc=13,          # Changed from 13 to 25
        n_mels=26,          # Custom Mel banks (closer to study's "25–42")
        hop_length=256      # Match segmentation hop_length
    )
        mfccs_mean = np.mean(mfccs.T, axis=0)
        mfccs_std = np.std(mfccs.T, axis=0)
        
        # Heartbeat timing features
        hop_length = 256  # Must match preprocessing value
        peak_times = librosa.frames_to_time(peaks, sr=sr, hop_length=hop_length)
        
        heartbeat_features = {}
        if len(peak_times) >= 2:
            intervals = np.diff(peak_times)

            # Group intervals into pairs (S1-S2 + S2-S1 = one complete cycle)
            cycle_intervals = []
            for i in range(0, len(intervals)-1, 2):
                cycle_intervals.append(intervals[i] + intervals[i+1])
            
            systole_times = intervals[::2] if len(intervals) > 1 else []
            diastole_times = intervals[1::2] if len(intervals) > 1 else []
            
            if len(systole_times) > 0:
                heartbeat_features.update({
                    "Systole_Mean": float(np.mean(systole_times)),
                    "Systole_Std": float(np.std(systole_times))
                })
            if len(diastole_times) > 0:
                heartbeat_features.update({
                    "Diastole_Mean": float(np.mean(diastole_times)),
                    "Diastole_Std": float(np.std(diastole_times))
                })
            # Calculate heart rate using complete cardiac cycles
            heartbeat_features["HeartRate"] = float(60/np.mean(cycle_intervals) if cycle_intervals else 
                                                60/np.mean(intervals)/2)  # Divide by 2 if using raw intervals
        
        # Spectral features
        spectral_contrast = librosa.feature.spectral_contrast(
            y=preprocessed_audio, sr=sr, fmin=20.0, n_bands=3
        )
        spectral_contrast_mean = np.mean(spectral_contrast, axis=1)
        
        # Broader, physiologically relevant energy bands
        bands = [
            (20, 100),   # S1 fundamental frequencies
            (100, 200),  # S2 fundamental frequencies
            (200, 400)   # Murmur frequencies
        ]
        band_energies = []
        for low, high in bands:
            spec = np.abs(librosa.stft(preprocessed_audio))
            freq_bins = librosa.fft_frequencies(sr=sr)
            idx_low = np.searchsorted(freq_bins, low)
            idx_high = np.searchsorted(freq_bins, high)
            band_energy = np.sum(np.mean(spec[idx_low:idx_high], axis=1))
            band_energies.append(band_energy)

        # Add wavelet decomposition
        def compute_wavelet_features(signal, sr, wavelet='db4', levels=4):
            """Extract comprehensive wavelet features for heart sound analysis"""
            # Perform wavelet decomposition
            coeffs = pywt.wavedec(signal, wavelet, level=levels)
            
            wavelet_features = {}
            
            # For each decomposition level
            for i, c in enumerate(coeffs):
                # Energy features
                wavelet_features[f'Wavelet_{i}_Energy'] = float(np.sum(c**2))
                
                # Shannon entropy
                normalized_c = c**2 / (np.sum(c**2) + 1e-12)
                wavelet_features[f'Wavelet_{i}_Shannon'] = float(-np.sum(normalized_c * np.log2(normalized_c + 1e-12)))
                
                # Ratio between adjacent scales (helps detect transients like S1/S2)
                if i < len(coeffs)-1:
                    energy_ratio = np.sum(c**2) / (np.sum(coeffs[i+1]**2) + 1e-12)
                    wavelet_features[f'Wavelet_{i}_EnergyRatio'] = float(energy_ratio)
            
            return wavelet_features

        wavelet_features = compute_wavelet_features(preprocessed_audio, sr)
        features.update(wavelet_features)

        # Q-Factor
        def compute_q_factor(signal, sr):
            spec = np.abs(librosa.stft(signal))
            freq_bins = librosa.fft_frequencies(sr=sr)
            peak_freq = freq_bins[np.argmax(np.mean(spec, axis=1))]
            bandwidth = librosa.feature.spectral_bandwidth(S=spec)[0].mean()
            return float(peak_freq / bandwidth if bandwidth > 0 else 0)
        
        features['Q_Factor'] = compute_q_factor(preprocessed_audio, sr)

        # Additional spectral features
        spectral_flatness = librosa.feature.spectral_flatness(y=preprocessed_audio)
        features['SpectralFlatness'] = float(np.mean(spectral_flatness))
        
        # Feature compilation
        features.update({
            # Timing and rhythm features
            **heartbeat_features, 
            
            # Spectral features
            **{f"MFCC_mean_{i+1}": float(v) for i, v in enumerate(mfccs_mean)},
            **{f"MFCC_std_{i+1}": float(v) for i, v in enumerate(mfccs_std)},
            **{f"SpectralContrast_{i+1}": float(v) for i, v in enumerate(spectral_contrast_mean)},
            
            # Energy distribution
            **{f"Energy_{low}_{high}Hz": float(e) for (low, high), e in zip(bands, band_energies)},
            
            # Additional features
            "ZeroCrossingRate": float(np.mean(librosa.feature.zero_crossing_rate(preprocessed_audio))),
            "SpectralFlatness": float(np.mean(spectral_flatness))
        })
        
        # If segmentation data provided, run validation
        validation_info = {}
        if segmentation_file and os.path.exists(segmentation_file):
            segmentation = load_segmentation_data(segmentation_file)
            if segmentation is not None:
                # Get detected peak times from full audio
                peak_times_full = librosa.frames_to_time(
                    peaks, sr=sr, hop_length=hop_length
                )
                
                # Filter for specific heart sound segments (classes 1 and 2 appear to be S1 and S2)
                s1_segments = segmentation[segmentation['segment_class'] == 1]
                s2_segments = segmentation[segmentation['segment_class'] == 2]
                
                # Calculate matches
                s1_matches = []
                for _, row in s1_segments.iterrows():
                    s1_start, s1_end = row['start_time'], row['end_time']
                    # Add a small tolerance window
                    tolerance = 0.1  # 100ms tolerance
                    found = False
                    for peak_time in peak_times_full:
                        if (s1_start - tolerance) <= peak_time <= (s1_end + tolerance):
                            found = True
                            break
                    s1_matches.append(found)
                
                s2_matches = []
                for _, row in s2_segments.iterrows():
                    s2_start, s2_end = row['start_time'], row['end_time']
                    tolerance = 0.1  # 100ms tolerance
                    found = False
                    for peak_time in peak_times_full:
                        if (s2_start - tolerance) <= peak_time <= (s2_end + tolerance):
                            found = True
                            break
                    s2_matches.append(found)
                
                # Calculate validation metrics
                s1_match_rate = sum(s1_matches) / len(s1_matches) if s1_matches else 0
                s2_match_rate = sum(s2_matches) / len(s2_matches) if s2_matches else 0
                total_match_rate = (sum(s1_matches) + sum(s2_matches)) / (len(s1_matches) + len(s2_matches)) if (s1_matches or s2_matches) else 0
                
                # Append validation info to features
                validation_info = {
                    "S1_Match_Rate": s1_match_rate,
                    "S2_Match_Rate": s2_match_rate, 
                    "Total_Match_Rate": total_match_rate,
                    "Total_Detected_Peaks": len(peak_times_full),
                    "Total_S1_Segments": len(s1_segments),
                    "Total_S2_Segments": len(s2_segments)
                }
                
                # Create validation visualization
                create_validation_plot(file_path, full_audio, sr, peak_times_full, segmentation)

        features = select_optimal_features(features)
        
        return features, validation_info
        
    except Exception as e:
        return {"error": f"Feature extraction error: {str(e)}"}, {}

def create_validation_plot(file_path, audio, sr, detected_peaks, segmentation):
    """Create an enhanced plot comparing detected peaks with segmentation data"""
    plt.figure(figsize=(15, 10))
    
    # Create multiple subplots
    gs = plt.GridSpec(3, 1, height_ratios=[2, 1, 1])
    
    # 1. Main waveform plot with segmentation
    ax1 = plt.subplot(gs[0])
    times = np.arange(len(audio)) / sr
    ax1.plot(times, audio, color='grey', alpha=0.7, label='Waveform')
    
    # Plot detected peaks
    for peak_time in detected_peaks:
        ax1.axvline(x=peak_time, color='red', linestyle='--', alpha=0.7, 
                   label='Detected Peak' if peak_time == detected_peaks[0] else '')
    
    # Plot segmentation with more informative color scheme
    colors = {1: 'green', 2: 'blue', 3: 'purple', 4: 'orange', 0: 'grey'}
    labels = {1: 'S1', 2: 'Systole', 3: 'S2', 4: 'Diastole', 0: 'Unknown'}
    
    legend_added = set()
    
    for _, row in segmentation.iterrows():
        class_id = row['segment_class']
        color = colors.get(class_id, 'grey')
        label = labels.get(class_id, f'Class {class_id}')
        
        if class_id not in legend_added:
            ax1.axvspan(row['start_time'], row['end_time'], alpha=0.3, color=color, label=label)
            legend_added.add(class_id)
        else:
            ax1.axvspan(row['start_time'], row['end_time'], alpha=0.3, color=color)
    
    ax1.set_title(f'Heart Sound Analysis: {os.path.basename(file_path)}')
    ax1.set_ylabel('Amplitude')
    ax1.legend(loc='upper right')
    ax1.grid(True, alpha=0.3)
    
    # 2. Spectrogram plot
    ax2 = plt.subplot(gs[1], sharex=ax1)
    D = librosa.amplitude_to_db(np.abs(librosa.stft(audio)), ref=np.max)
    librosa.display.specshow(D, y_axis='log', x_axis='time', sr=sr, ax=ax2)
    ax2.set_ylabel('Frequency (Hz)')
    ax2.set_title('Spectrogram')
    
    # 3. Onset strength plot
    ax3 = plt.subplot(gs[2], sharex=ax1)
    hop_length = 256  # Make sure this matches what was used in preprocessing
    onset_env = librosa.onset.onset_strength(y=audio, sr=sr, hop_length=hop_length)
    times_onset = librosa.times_like(onset_env, sr=sr, hop_length=hop_length)
    ax3.plot(times_onset, onset_env, label='Onset Strength')
    ax3.set_ylabel('Strength')
    ax3.set_xlabel('Time (s)')
    ax3.set_title('Onset Strength')
    
    # Mark detected peaks on onset strength plot
    frame_peaks = librosa.time_to_frames(detected_peaks, sr=sr, hop_length=hop_length)
    for p in frame_peaks:
        if p < len(onset_env):
            ax3.plot(times_onset[p], onset_env[p], 'ro', markersize=8)
    
    plt.tight_layout()
    
    # Calculate accuracy statistics
    s1_segments = segmentation[segmentation['segment_class'] == 1]
    s2_segments = segmentation[segmentation['segment_class'] == 2]
    
    # Count true positives (peaks within segment boundaries)
    s1_matches = sum(1 for _, row in s1_segments.iterrows() 
                    if any(row['start_time'] <= p <= row['end_time'] for p in detected_peaks))
    s2_matches = sum(1 for _, row in s2_segments.iterrows() 
                    if any(row['start_time'] <= p <= row['end_time'] for p in detected_peaks))
    
    # Add accuracy stats to the plot
    stats_text = (f"S1 Detection Rate: {s1_matches}/{len(s1_segments)} ({s1_matches/len(s1_segments)*100:.1f}%)\n"
                 f"S2 Detection Rate: {s2_matches}/{len(s2_segments)} ({s2_matches/len(s2_segments)*100:.1f}%)\n"
                 f"Total Peaks Detected: {len(detected_peaks)}")
    
    plt.figtext(0.02, 0.02, stats_text, fontsize=10, bbox=dict(facecolor='white', alpha=0.8))
    
    # Save plot
    plot_file = os.path.splitext(file_path)[0] + '_validation.png'
    plt.savefig(plot_file, dpi=300, bbox_inches='tight')
    print(f"Enhanced validation plot saved to {plot_file}")
    plt.close()

if __name__ == "__main__":
    try:
        if len(sys.argv) < 2:
            print(json.dumps({"error": "Usage: python extract_features.py <file.wav> [segmentation_file.txt]"}))
            sys.exit(1)
        
        wav_file = sys.argv[1]
        segmentation_file = sys.argv[2] if len(sys.argv) > 2 else None
        
        features, validation = extract_features(wav_file, segmentation_file)
        
        if isinstance(features, dict):
            if "error" in features:
                print(f"Error: {features['error']}")
            else:
                print("\nExtracted Features:")
                print("-" * 50)
                # Print in order: MFCCs, Spectral Contrast, ZCR
                for feature in sorted(features.keys()):
                    value = features[feature]
                    print(f"{feature:20}: {value:.6f}")
                print("-" * 50)
                
                if validation:
                    print("\nValidation Results:")
                    print("-" * 50)
                    for metric, value in validation.items():
                        print(f"{metric:20}: {value:.2%}" if "Rate" in metric else f"{metric:20}: {value}")
                    print("-" * 50)
                
                print("\nJSON output:")
                print(json.dumps(features))
            
    except Exception as e:
        print(json.dumps({"error": str(e)}))
// lib/utils/learning_center_initializer.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../utils/learning_center_models.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// A utility class to initialize the Learning Center data in Firebase
class LearningCenterInitializer {
  final DatabaseReference _database;
  final FirebaseStorage _storage;
  final BuildContext context;
  final Function(String) showMessage;
  final Function(String, double) updateProgress;

  LearningCenterInitializer({
    required this.context,
    required this.showMessage,
    required this.updateProgress,
  }) : _database = FirebaseDatabase.instance.ref(),
       _storage = FirebaseStorage.instance;

  /// Initialize all Learning Center data
  Future<void> initializeAllData() async {
    try {
      updateProgress('Starting initialization...', 0.0);
      
      // Create base path
      await _database.child('learningCenter').set({
        'initialized': true,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      updateProgress('Initializing topics...', 0.1);
      await initializeTopics();
      
      updateProgress('Initializing heart murmurs...', 0.3);
      await initializeHeartMurmurs();
      
      updateProgress('Initializing quizzes...', 0.7);
      await initializeQuizzes();
      
      updateProgress('Initialization complete!', 1.0);
      showMessage('Learning Center data initialized successfully!');
    } catch (e) {
      showMessage('Error initializing data: $e');
      rethrow;
    }
  }

  /// Upload heart murmur audio files
  Future<void> uploadHeartMurmurAudio() async {
    try {
      updateProgress('Selecting audio files...', 0.0);
      
      // Pick multiple files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      
      if (result == null || result.files.isEmpty) {
        showMessage('No files selected');
        return;
      }
      
      final files = result.files;
      int totalFiles = files.length;
      int uploadedFiles = 0;
      
      for (var file in files) {
        if (file.path == null) continue;
        
        final fileName = path.basename(file.path!);
        path.extension(fileName);
        final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
        
        updateProgress('Uploading $fileName...', uploadedFiles / totalFiles);
        
        // Upload file to storage
        final storageRef = _storage.ref().child('audio/heart_murmurs/$fileName');
        final uploadTask = storageRef.putFile(File(file.path!));
        
        await uploadTask.whenComplete(() {});
        final downloadUrl = await storageRef.getDownloadURL();
        
        // Create murmur data entry if it doesn't exist
        final murmurRef = _database.child('learningCenter/heartMurmurs/$fileNameWithoutExt');
        final snapshot = await murmurRef.get();
        
        if (!snapshot.exists) {
          await murmurRef.set({
            'id': fileNameWithoutExt,
            'name': _capitalizeWords(fileNameWithoutExt.replaceAll('_', ' ')),
            'description': 'Heart murmur sound',
            'position': 'Not specified',
            'timing': 'Not specified',
            'quality': 'Not specified',
            'grade': 'Not specified',
            'audioUrl': 'audio/heart_murmurs/$fileName',
            'downloadUrl': downloadUrl,
            'clinicalImplications': ['Not specified'],
          });
        } else {
          // Update only the audioUrl field
          await murmurRef.update({
            'audioUrl': 'audio/heart_murmurs/$fileName',
            'downloadUrl': downloadUrl,
          });
        }
        
        uploadedFiles++;
      }
      
      updateProgress('All files uploaded successfully!', 1.0);
      showMessage('$uploadedFiles audio files uploaded successfully!');
    } catch (e) {
      showMessage('Error uploading audio files: $e');
      rethrow;
    }
  }

  /// Initialize learning topics
  Future<void> initializeTopics() async {
    final topics = _getDefaultTopics();
    final topicsRef = _database.child('learningCenter/topics');
    
    for (var topic in topics) {
      await topicsRef.child(topic.id).set(topic.toMap());
      updateProgress('Topic ${topic.title} initialized', 0.1 + (0.2 * topics.indexOf(topic) / topics.length));
    }
  }

  /// Initialize heart murmurs
  Future<void> initializeHeartMurmurs() async {
    final murmurs = _getDefaultHeartMurmurs();
    final murmursRef = _database.child('learningCenter/heartMurmurs');
    
    for (var murmur in murmurs) {
      await murmursRef.child(murmur.id).set(murmur.toMap());
      updateProgress('Murmur ${murmur.name} initialized', 0.3 + (0.4 * murmurs.indexOf(murmur) / murmurs.length));
    }
  }

  /// Initialize quizzes
  Future<void> initializeQuizzes() async {
    final quizzes = _getDefaultQuizzes();
    final quizzesRef = _database.child('learningCenter/quizzes');
    
    for (var quiz in quizzes) {
      await quizzesRef.child(quiz.id).set(quiz.toMap());
      updateProgress('Quiz ${quiz.title} initialized', 0.7 + (0.3 * quizzes.indexOf(quiz) / quizzes.length));
    }
  }

  /// Get default learning topics
  List<LearningTopic> _getDefaultTopics() {
   return [
    // ECG Topics
    LearningTopic(
      id: 'ecg_basics',
      title: 'ECG Basics',
      description: 'Learn the fundamentals of electrocardiogram (ECG) interpretation.',
      resources: [
        LearningResource(
          id: 'ecg_intro',
          title: 'Introduction to ECG',
          content: '''
# Introduction to Electrocardiogram (ECG)

An electrocardiogram (ECG or EKG) is a test that records the electrical activity of the heart. It is a non-invasive procedure used to diagnose heart conditions.

## How ECG Works

The heart's electrical activity creates signals that are detected by electrodes placed on the skin. These signals are amplified and recorded by the ECG machine.

## Clinical Applications

ECGs are used to:
- Detect arrhythmias (abnormal heart rhythms)
- Identify heart attacks (myocardial infarction)
- Evaluate the effects of medications on the heart
- Monitor pacemaker function
- Screen for heart disease

ECG is one of the most commonly used diagnostic tools in cardiology.
''',
          type: 'text',
        ),
        LearningResource(
          id: 'ecg_components',
          title: 'ECG Components',
          content: '''
# ECG Components and Interpretation

The main components of an ECG tracing include:

## P Wave
- Represents atrial depolarization (contraction of the atria)
- Normal duration: 0.08-0.12 seconds
- Normal amplitude: 0.5-2.5 mm

## PR Interval
- Measured from the beginning of the P wave to the beginning of the QRS complex
- Represents the time for electrical impulse to travel from the atria to the ventricles
- Normal duration: 0.12-0.20 seconds

## QRS Complex
- Represents ventricular depolarization (contraction of the ventricles)
- Normal duration: 0.06-0.10 seconds

## ST Segment
- Represents the early phase of ventricular repolarization
- Normally isoelectric (neither elevated nor depressed)

## T Wave
- Represents ventricular repolarization
- Normal duration: 0.16 seconds
- Normal amplitude: 0.5 mm in limb leads, 2.5 mm in precordial leads

## QT Interval
- Measured from the beginning of the QRS complex to the end of the T wave
- Represents total ventricular activity
- Normal duration: 0.36-0.44 seconds (varies with heart rate)

Understanding these components is essential for accurate ECG interpretation.
''',
          type: 'text',
        ),
        LearningResource(
          id: 'ecg_leads',
          title: 'ECG Leads and Placement',
          content: '''
# ECG Leads and Electrode Placement

The standard 12-lead ECG consists of:

## Limb Leads (6)
- **Standard Limb Leads (I, II, III)**: Bipolar leads measuring potential difference between two limbs
- **Augmented Limb Leads (aVR, aVL, aVF)**: Unipolar leads measuring potential at one limb relative to a reference point

## Precordial (Chest) Leads (6)
- **V1**: 4th intercostal space, right sternal border
- **V2**: 4th intercostal space, left sternal border
- **V3**: Midway between V2 and V4
- **V4**: 5th intercostal space, left midclavicular line
- **V5**: Same level as V4, left anterior axillary line
- **V6**: Same level as V4, left midaxillary line

## Lead Placement Significance
Each lead provides a different "view" of the heart's electrical activity:
- **Inferior wall**: Leads II, III, aVF
- **Lateral wall**: Leads I, aVL, V5, V6
- **Anterior wall**: Leads V1-V4
- **Septal wall**: Leads V1, V2
- **Right ventricle**: Leads V1, V3R, V4R (right-sided chest leads)

Proper lead placement is critical for accurate ECG interpretation.
''',
          type: 'text',
        ),
      ],
    ),
    LearningTopic(
      id: 'ecg_arrhythmias',
      title: 'ECG Arrhythmias',
      description: 'Learn to identify various cardiac arrhythmias on ECG.',
      resources: [
        LearningResource(
          id: 'sinus_rhythms',
          title: 'Sinus Rhythms',
          content: '''
# Sinus Rhythms

Sinus rhythms originate from the sinus node, the heart's natural pacemaker located in the right atrium.

## Normal Sinus Rhythm (NSR)
- Rate: 60-100 beats per minute
- Regular rhythm
- Normal P waves preceding each QRS complex
- Normal PR interval (0.12-0.20 seconds)
- Normal QRS duration (0.06-0.10 seconds)

## Sinus Bradycardia
- Rate: <60 beats per minute
- Regular rhythm
- Normal P waves and QRS complexes
- Common in athletes or during sleep
- Can be caused by medications (beta-blockers, calcium channel blockers)

## Sinus Tachycardia
- Rate: >100 beats per minute
- Regular rhythm
- Normal P waves and QRS complexes
- Common during exercise, anxiety, fever, pain
- Can be caused by medications, hyperthyroidism, anemia

## Sinus Arrhythmia
- Variation in heart rate with respiration
- Increases during inspiration, decreases during expiration
- Normal P waves and QRS complexes
- Common in children and young adults
- Usually benign

## Sinus Pause/Arrest
- Temporary absence of sinus node activity
- Pause in the cardiac cycle
- May cause symptoms if prolonged
- Can be caused by increased vagal tone or sinus node dysfunction

Understanding sinus rhythms is foundational for recognizing more complex arrhythmias.
''',
          type: 'text',
        ),
        LearningResource(
          id: 'atrial_arrhythmias',
          title: 'Atrial Arrhythmias',
          content: '''
# Atrial Arrhythmias

Atrial arrhythmias originate in the atria, above the AV node.

## Premature Atrial Contractions (PACs)
- Early beat originating from an ectopic atrial focus
- Abnormal P wave morphology
- Usually followed by a normal QRS complex
- Often benign but may be associated with atrial enlargement, electrolyte abnormalities

## Atrial Fibrillation (AFib)
- Chaotic electrical activity in the atria
- Irregular, "irregularly irregular" rhythm
- Absence of distinct P waves, replaced by fibrillatory waves
- Variable ventricular response rate
- Risk of thromboembolic events (e.g., stroke)

## Atrial Flutter
- Rapid, regular atrial activity (typically 250-350 bpm)
- Characteristic "sawtooth" pattern of flutter waves
- Usually with 2:1, 3:1, or 4:1 AV conduction
- Associated with heart failure, valvular disease, or COPD

## Multifocal Atrial Tachycardia (MAT)
- ≥3 different P wave morphologies
- Irregular rhythm
- Rate typically 100-150 bpm
- Often seen in patients with severe pulmonary disease

## Supraventricular Tachycardia (SVT)
- Rapid regular rhythm (typically 150-250 bpm)
- Narrow QRS complexes
- P waves may be hidden in T waves
- Includes AVNRT, AVRT, and atrial tachycardia

Proper identification of atrial arrhythmias is crucial for appropriate management.
''',
          type: 'text',
        ),
        LearningResource(
          id: 'ventricular_arrhythmias',
          title: 'Ventricular Arrhythmias',
          content: '''
# Ventricular Arrhythmias

Ventricular arrhythmias originate below the bundle of His in the ventricles.

## Premature Ventricular Contractions (PVCs)
- Early beats originating from an ectopic ventricular focus
- Wide, bizarre QRS complexes (>0.12 seconds)
- No preceding P wave
- Usually followed by a compensatory pause
- Can be isolated, bigeminy (every other beat), trigeminy (every third beat), or couplets

## Ventricular Tachycardia (VT)
- Three or more consecutive PVCs
- Rate typically 100-250 bpm
- Wide QRS complexes with AV dissociation
- Can be monomorphic (same QRS morphology) or polymorphic (varying QRS morphology)
- Often associated with structural heart disease
- Can lead to hemodynamic compromise and sudden cardiac death

## Torsades de Pointes
- Specific type of polymorphic VT
- Characterized by "twisting of points" appearance
- Associated with prolonged QT interval
- Can be caused by medications, electrolyte abnormalities

## Ventricular Fibrillation (VFib)
- Chaotic, rapid ventricular activity
- No discernible QRS complexes, just irregular undulations
- No effective cardiac output
- Immediate cause of cardiac arrest
- Requires immediate defibrillation

## Idioventricular Rhythm
- Ventricular escape rhythm
- Rate typically 20-40 bpm
- Wide QRS complexes
- Occurs when higher pacemakers fail

Ventricular arrhythmias can be life-threatening and require prompt recognition and management.
''',
          type: 'text',
        ),
        LearningResource(
          id: 'heart_blocks',
          title: 'Heart Blocks',
          content: '''
# Heart Blocks

Heart blocks involve disruption of impulse conduction through the heart's electrical conduction system.

## First-Degree AV Block
- Prolonged PR interval (>0.20 seconds)
- Every P wave followed by a QRS complex
- Normal QRS duration
- Often asymptomatic
- Can be caused by medications, increased vagal tone, or ischemia

## Second-Degree AV Block: Mobitz Type I (Wenckebach)
- Progressive PR interval prolongation until a P wave is not conducted
- Grouped beating pattern
- Usually narrow QRS complexes
- Often transient and asymptomatic
- Typically benign if no underlying heart disease

## Second-Degree AV Block: Mobitz Type II
- Sudden failure of conduction without progressive PR prolongation
- Fixed PR interval in conducted beats
- Often wide QRS complexes
- More concerning than Mobitz I
- May progress to complete heart block
- Often requires pacemaker implantation

## Third-Degree (Complete) AV Block
- Complete dissociation between atrial and ventricular activity
- P waves bear no relationship to QRS complexes
- Ventricular rate typically 30-40 bpm (junctional escape) or <30 bpm (ventricular escape)
- QRS duration depends on escape pacemaker location
- Symptomatic (fatigue, syncope)
- Usually requires pacemaker implantation

## Bundle Branch Blocks
- **Right Bundle Branch Block (RBBB)**: QRS ≥0.12 seconds, RSR' pattern in V1, wide S wave in I and V6
- **Left Bundle Branch Block (LBBB)**: QRS ≥0.12 seconds, broad monophasic R wave in I and V6, absence of Q waves in I, V5, V6

Understanding heart blocks is essential for recognizing potential causes of bradycardia and determining appropriate intervention.
''',
          type: 'text',
        ),
      ],
    ),
    LearningTopic(
      id: 'ecg_myocardial_infarction',
      title: 'ECG in Myocardial Infarction',
      description: 'Learn to recognize ECG changes in acute coronary syndromes and myocardial infarction.',
      resources: [
        LearningResource(
          id: 'stemi_identification',
          title: 'STEMI Identification',
          content: '''
# ST-Elevation Myocardial Infarction (STEMI) Identification

STEMI represents myocardial infarction with full-thickness damage requiring immediate reperfusion therapy.

## ECG Criteria for STEMI
- ST-segment elevation at the J point in 2 contiguous leads:
  - ≥1 mm elevation in all leads except V2-V3
  - For V2-V3: ≥2 mm in men ≥40 years, ≥2.5 mm in men <40 years, or ≥1.5 mm in women
- ST elevation should be new or presumed new
- In the context of symptoms consistent with myocardial ischemia

## Localization of Infarction
- **Anterior STEMI**: ST elevation in V1-V4
  - LAD artery occlusion
- **Inferior STEMI**: ST elevation in II, III, aVF
  - RCA or circumflex artery occlusion
- **Lateral STEMI**: ST elevation in I, aVL, V5, V6
  - Circumflex or diagonal branch occlusion
- **Posterior STEMI**: ST depression in V1-V3 with tall R waves
  - Circumflex or RCA occlusion
- **Right Ventricular STEMI**: ST elevation in right-sided leads (V3R, V4R)
  - Proximal RCA occlusion

## Evolution of STEMI on ECG
1. **Hyperacute phase** (minutes to hours): Tall, peaked T waves
2. **Acute phase** (hours to days): ST-segment elevation, Q wave formation
3. **Subacute phase** (days to weeks): ST resolution, T wave inversion
4. **Chronic phase** (weeks to permanent): Q waves, T wave normalization

## STEMI Mimics
- Left ventricular hypertrophy
- Left bundle branch block
- Brugada syndrome
- Early repolarization
- Pericarditis
- Hyperkalemia
- Left ventricular aneurysm

Prompt recognition of STEMI is critical for timely reperfusion therapy and improved outcomes.
''',
          type: 'text',
        ),
        LearningResource(
          id: 'nstemi_unstable_angina',
          title: 'NSTEMI and Unstable Angina',
          content: '''
# NSTEMI and Unstable Angina

Non-ST-elevation myocardial infarction (NSTEMI) and unstable angina represent acute coronary syndromes without ST elevation.

## ECG Changes in NSTEMI
- ST-segment depression (horizontal or downsloping)
- T wave inversion
- Transient ST elevation
- Normal ECG in ~30% of cases

## Differentiating NSTEMI from Unstable Angina
- NSTEMI: Elevated cardiac biomarkers (troponin)
- Unstable angina: Normal cardiac biomarkers

## High-Risk ECG Features
- Dynamic ST changes (≥0.5 mm)
- Deep symmetrical T wave inversions in multiple leads
- New onset LBBB
- Sustained ventricular arrhythmias
- Hemodynamically significant bradyarrhythmias

## ECG Localization in NSTEMI
- Anterior (V1-V4): LAD territory
- Inferior (II, III, aVF): RCA/circumflex territory
- Lateral (I, aVL, V5, V6): Circumflex/diagonal territory

## Wellens Syndrome
- Deeply inverted or biphasic T waves in V2-V3
- Minimal or no ST elevation
- Minimal or no cardiac enzyme elevation
- Predictor of critical LAD stenosis

## De Winter T-wave Pattern
- Upsloping ST depression with tall, symmetric T waves in V1-V6
- Equivalent to anterior STEMI, indicating LAD occlusion

Recognition of these ECG patterns is crucial for risk stratification and management of non-ST-elevation acute coronary syndromes.
''',
          type: 'text',
        ),
      ],
    ),

    // PulseOx Topics
LearningTopic(
  id: 'pulseox_basics',
  title: 'Pulse Oximetry Fundamentals',
  description: 'Understanding pulse oximetry measurements and clinical significance.',
  resources: [
    LearningResource(
      id: 'pulseox_intro',
      title: 'Introduction to Pulse Oximetry',
      content: '''
# Introduction to Pulse Oximetry

Pulse oximetry is a non-invasive method for monitoring a person's oxygen saturation and heart rate.

## How Pulse Oximetry Works

Pulse oximeters work by emitting light of different wavelengths (typically red and infrared) through a translucent part of the body, usually a fingertip or earlobe. The device measures how much light is absorbed by oxygenated and deoxygenated hemoglobin in the blood.

## SpO2 Measurement

- SpO2 (peripheral oxygen saturation) is the percentage of hemoglobin that is saturated with oxygen.
- Normal SpO2 values range from 95% to 100% in healthy individuals.
- Values below 90% indicate hypoxemia and may require medical intervention.

## Clinical Applications

Pulse oximetry is used in:
- Monitoring patients in critical care
- Sleep studies for detecting sleep apnea
- Assessing patients with respiratory conditions
- Monitoring during anesthesia
- Home monitoring for patients with chronic respiratory diseases

## Limitations

Factors that can affect accuracy include:
- Poor peripheral circulation
- Nail polish or artificial nails
- Motion artifacts
- Severe anemia
- Carbon monoxide poisoning (can give falsely high readings)

Proper understanding of pulse oximetry is essential for healthcare providers to ensure accurate monitoring and interpretation.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'pulseox_technical_principles',
      title: 'Technical Principles of Pulse Oximetry',
      content: '''
# Technical Principles of Pulse Oximetry

Pulse oximetry is based on the principles of spectrophotometry and plethysmography.

## Beer-Lambert Law

Pulse oximetry applies the Beer-Lambert law, which states that the concentration of a solute in solution is proportional to the amount of light absorbed by the solution.

## Light Absorption Properties

- **Oxygenated hemoglobin (HbO2)** absorbs more infrared light (940 nm) and less red light (660 nm)
- **Deoxygenated hemoglobin (Hb)** absorbs more red light and less infrared light

## Ratio of Ratios (R)

The pulse oximeter calculates the ratio of absorption of red light to infrared light, which correlates with oxygen saturation:

R = (AC660/DC660) / (AC940/DC940)

Where:
- AC = pulsatile component of absorption
- DC = constant absorption by tissues, venous blood, and non-pulsatile arterial blood
- 660 and 940 = wavelengths in nanometers

The R value is converted to SpO2 using a calibration curve derived from empirical data.

## Signal Processing

Modern pulse oximeters use sophisticated signal processing to:
- Filter out noise and motion artifacts
- Identify and analyze the pulsatile component
- Average readings over time to increase accuracy
- Detect and compensate for low perfusion states

## Display Components

Standard pulse oximeters display:
- SpO2 (oxygen saturation percentage)
- Pulse rate
- Plethysmographic waveform (visual representation of pulse volume)

Understanding these technical principles helps clinicians interpret pulse oximetry readings accurately and recognize potential sources of error.
''',
      type: 'text',
    ),
  ],
),
LearningTopic(
  id: 'pulseox_clinical_applications',
  title: 'Clinical Applications of Pulse Oximetry',
  description: 'Learn how pulse oximetry is used in various clinical settings and disease states.',
  resources: [
    LearningResource(
      id: 'pulseox_respiratory_disease',
      title: 'Pulse Oximetry in Respiratory Disease',
      content: '''
# Pulse Oximetry in Respiratory Disease

Pulse oximetry plays a crucial role in the assessment and management of respiratory conditions.

## Chronic Obstructive Pulmonary Disease (COPD)

- Baseline SpO2 may be lower (88-92%) in patients with chronic respiratory failure
- Used to titrate supplemental oxygen (target usually 88-92% to avoid CO2 retention)
- Important for monitoring during exacerbations
- Helps determine need for hospital admission
- Useful in pulmonary rehabilitation programs

## Asthma

- Helps assess severity of exacerbations
- Normal SpO2 during asthma attack may indicate mild exacerbation
- SpO2 <92% indicates severe exacerbation requiring aggressive treatment
- Useful for monitoring response to therapy
- Can help detect early deterioration before clinical symptoms worsen

## Pneumonia

- SpO2 <90% is associated with increased mortality
- Helps determine need for hospitalization (CURB-65 criteria)
- Useful for monitoring disease progression and response to antibiotics
- Portable oximetry allows home monitoring for selected patients

## Pulmonary Embolism

- Normal SpO2 doesn't rule out PE (can have normal values in up to 40% of cases)
- Sudden drop in SpO2 without other explanation should raise suspicion
- Used to monitor response to anticoagulation or thrombolytic therapy
- Helpful in risk stratification when combined with other clinical parameters

## Interstitial Lung Disease

- Resting hypoxemia often present in advanced disease
- Exercise-induced desaturation is common and may occur before resting hypoxemia
- 6-minute walk test with continuous oximetry helps assess disease severity
- Useful for monitoring disease progression and response to therapy
- Helps determine need for supplemental oxygen

## Sleep-Disordered Breathing

- Overnight oximetry can screen for sleep apnea
- Characteristic "sawtooth" pattern of recurrent desaturations
- Not as sensitive as polysomnography but more accessible
- Useful for monitoring CPAP compliance and effectiveness
- Home oximetry allows for convenient screening and monitoring

Pulse oximetry provides valuable information for diagnosis, assessment of severity, monitoring of disease progression, and evaluation of treatment response in respiratory conditions.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'pulseox_critical_care',
      title: 'Pulse Oximetry in Critical Care',
      content: '''
# Pulse Oximetry in Critical Care

Pulse oximetry is an essential monitoring tool in critical care settings.

## Mechanical Ventilation

- Continuous monitoring to ensure adequate oxygenation
- Guides titration of FiO2 and PEEP
- Helps detect ventilator disconnection or malfunction
- Monitors response to recruitment maneuvers
- Assists in weaning assessment
- May be coupled with end-tidal CO2 monitoring for more comprehensive respiratory assessment

## Shock States

- Decreased perfusion may affect accuracy (peripheral vasoconstriction)
- Can help detect hypoxemia before clinical cyanosis
- Trending more valuable than absolute values in hypoperfusion
- Consider central monitoring sites (earlobe, forehead) when peripheral perfusion is poor
- Plethysmographic waveform provides information about perfusion status

## Procedural Sedation

- Continuous monitoring required during conscious sedation
- Early warning of respiratory depression
- Guidelines recommend continuous monitoring during recovery
- Can detect hypoventilation before clinical signs develop
- Helps determine when supplemental oxygen can be discontinued

## Cardiopulmonary Resuscitation

- Helps assess effectiveness of CPR
- Can detect return of spontaneous circulation
- Guides oxygen therapy during post-resuscitation care
- Limitations during arrest due to poor peripheral perfusion
- More reliable once circulation is restored

## Transport of Critically Ill Patients

- Essential monitoring during intrahospital and interhospital transport
- Portable devices allow continuous monitoring
- Helps detect deterioration during transport
- Battery-powered devices ensure uninterrupted monitoring
- Combined with other portable monitoring (ECG, BP, capnography)

## Limitations in Critical Care

- Decreased accuracy in hypoperfusion states
- Motion artifacts during seizures or shivering
- Interference from ambient light in emergency settings
- May be affected by vasoactive medications
- Doesn't detect hyperoxia (excessive oxygen levels)
- Not a substitute for arterial blood gas analysis when precise measurements are needed

Understanding these applications and limitations helps critical care providers use pulse oximetry effectively as part of comprehensive patient monitoring.
''',
      type: 'text',
    ),
  ],
),
LearningTopic(
  id: 'pulseox_pediatric',
  title: 'Pulse Oximetry in Pediatrics',
  description: 'Understanding the applications and special considerations for pulse oximetry in pediatric patients.',
  resources: [
    LearningResource(
      id: 'pulseox_neonatal',
      title: 'Neonatal Pulse Oximetry',
      content: '''
# Neonatal Pulse Oximetry

Pulse oximetry has unique applications and considerations in neonatal care.

## Critical Congenital Heart Disease (CCHD) Screening

- Universal screening recommended for all newborns before discharge
- Targets ductal-dependent lesions that may not present symptoms initially
- Protocol:
  - Measure pre-ductal (right hand) and post-ductal (either foot) SpO2
  - Positive screen: SpO2 <90%, SpO2 difference >3% between pre/post-ductal sites, or failed repeat measurements
  - High sensitivity for CCHD when combined with physical examination
  - Cost-effective strategy for early detection

## Neonatal Resuscitation

- Goal SpO2 changes over time after birth:
  - 1 minute: 60-65%
  - 2 minutes: 65-70%
  - 3 minutes: 70-75%
  - 4 minutes: 75-80%
  - 5 minutes: 80-85%
  - 10 minutes: 85-95%
- Guides oxygen therapy during resuscitation
- Helps prevent hyperoxia, which can cause oxidative stress
- Right hand (pre-ductal) preferred site during resuscitation

## Respiratory Distress Syndrome (RDS)

- Continuous monitoring in NICU setting
- Guides surfactant administration
- Helps titrate oxygen therapy
- Target SpO2 ranges typically 90-95% for preterm infants
- Avoiding hyperoxia particularly important in premature infants (risk of retinopathy of prematurity)

## Technical Considerations

- Smaller sensors designed for neonatal use
- Motion artifact more common in active infants
- Perfusion index (PI) helpful in assessing sensor placement
- Proper size and placement crucial for accuracy
- May require longer averaging times for stable readings

## Limitations

- Less accurate during poor perfusion states
- Motion artifacts common during crying
- Transitional circulation affects interpretation in first hours of life
- May not detect hyperoxia, which is particularly dangerous in preterm infants
- Regular correlation with arterial blood gases recommended for ventilated infants

Neonatal pulse oximetry requires understanding of the unique physiology of newborns and careful attention to technical factors affecting accuracy.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'pulseox_pediatric_respiratory',
      title: 'Pediatric Respiratory Assessment',
      content: '''
# Pulse Oximetry in Pediatric Respiratory Assessment

Pulse oximetry is a cornerstone of respiratory assessment in pediatric patients.

## Bronchiolitis

- Helps determine illness severity
- SpO2 <90-92% often used as criterion for hospitalization
- Continuous monitoring recommended during acute phase
- May detect intermittent desaturations during feeding or sleep
- Home oximetry sometimes used for monitoring after discharge
- Limitation: doesn't predict which infants will deteriorate

## Asthma

- Part of standard assessment in acute exacerbations
- SpO2 <92% indicates severe exacerbation
- Normal SpO2 doesn't rule out significant airway obstruction
- Used in conjunction with clinical scores (e.g., PRAM, PASS)
- Serial measurements help evaluate response to treatment
- Can help determine timing of discharge from emergency department

## Croup

- Typically normal until severe upper airway obstruction
- Sudden desaturation indicates impending respiratory failure
- More sensitive than clinical assessment for detecting hypoxemia
- Useful when evaluating need for airway intervention
- Limited value in mild cases

## Pneumonia

- Helps distinguish pneumonia from simple viral illnesses
- SpO2 <92% increases likelihood of pneumonia
- Useful for monitoring response to antibiotics
- Part of severity assessment (e.g., PEWS score)
- Serial measurements guide oxygen weaning and discharge planning

## Foreign Body Aspiration

- May be normal despite significant obstruction
- Sudden desaturation may occur with position changes
- Continuous monitoring important during retrieval procedures
- Limited sensitivity as a screening tool

## Special Considerations

- Children with chronic conditions (e.g., cystic fibrosis, bronchopulmonary dysplasia) may have different baseline values
- Correlation with work of breathing essential (hypoxemia often late sign in pediatrics)
- Motion artifacts common in uncooperative children
- Toy-shaped or colorful oximeters can improve cooperation
- Consider measuring during sleep for conditions with intermittent desaturation

Pulse oximetry provides valuable objective data in pediatric respiratory assessment but must always be interpreted in the clinical context, considering the child's baseline status and work of breathing.
''',
      type: 'text',
    ),
  ],
),

// Heart Murmur Topics
LearningTopic(
  id: 'heart_murmurs',
  title: 'Heart Murmur Identification',
  description: 'Learn to identify and classify different types of heart murmurs.',
  resources: [
    LearningResource(
      id: 'murmur_basics',
      title: 'Heart Murmur Basics',
      content: '''
# Heart Murmur Basics

Heart murmurs are sounds caused by turbulent blood flow through the heart valves or near the heart. They are characterized by a "whooshing" or "swishing" sound heard during auscultation with a stethoscope.

## Classification of Heart Murmurs

Heart murmurs are classified based on several characteristics:

### 1. Timing
- **Systolic Murmurs**: Occur during ventricular contraction (between S1 and S2)
- **Diastolic Murmurs**: Occur during ventricular relaxation (between S2 and S1)
- **Continuous Murmurs**: Present throughout the cardiac cycle

### 2. Intensity (Grades)
- **Grade I**: Very faint, heard only in a quiet room with a skilled listener
- **Grade II**: Faint but easily heard
- **Grade III**: Moderately loud, no thrill (vibration) palpable
- **Grade IV**: Loud with a palpable thrill
- **Grade V**: Very loud with a thrill, audible with stethoscope partly off the chest
- **Grade VI**: Extremely loud, audible with stethoscope off the chest

### 3. Location
Murmurs are described by their location on the chest where they are best heard:
- Aortic area: 2nd right intercostal space
- Pulmonic area: 2nd left intercostal space
- Tricuspid area: Lower left sternal border
- Mitral area: Apex (5th intercostal space, midclavicular line)

### 4. Quality
- Harsh
- Blowing
- Musical
- Rumbling
- Machinery-like

### 5. Radiation
The direction in which the murmur radiates or transmits:
- To the neck (aortic stenosis)
- To the axilla (mitral regurgitation)
- To the back (patent ductus arteriosus)

## Clinical Significance

Heart murmurs can be:
- **Innocent/Physiological**: Not associated with cardiovascular disease, common in children
- **Pathological**: Indicate underlying heart disease

Accurate identification and characterization of heart murmurs are crucial for proper diagnosis and management of heart conditions.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'systolic_murmurs',
      title: 'Systolic Murmurs',
      content: '''
# Systolic Murmurs

Systolic murmurs occur between S1 (first heart sound) and S2 (second heart sound), during ventricular contraction.

## Early Systolic Murmurs
- Begin with S1 and end before S2
- Often caused by small ventricular septal defects or tricuspid regurgitation
- Brief in duration
- May decrease in intensity toward mid-systole

## Mid-Systolic (Ejection) Murmurs
- Begin after S1 and end before S2
- Diamond-shaped: crescendo-decrescendo pattern
- Caused by blood flow across semilunar valves or outflow tracts
- Common causes:
  - Aortic stenosis
  - Pulmonic stenosis
  - Hypertrophic cardiomyopathy
  - Flow murmurs (anemia, hyperthyroidism, pregnancy)

## Holosystolic (Pansystolic) Murmurs
- Begin with S1 and continue through S2
- Uniform intensity throughout systole
- Caused by blood flow from a high-pressure to low-pressure chamber throughout systole
- Common causes:
  - Mitral regurgitation
  - Tricuspid regurgitation
  - Ventricular septal defect

## Late Systolic Murmurs
- Begin in mid-systole and continue until S2
- Often preceded by a mid-systolic click
- Classic example: mitral valve prolapse
- Intensity may increase with standing or Valsalva maneuver

## Auscultation Techniques
- Position the patient appropriately (sitting, supine, left lateral decubitus)
- Use the diaphragm of the stethoscope for high-pitched murmurs
- Listen at all auscultation areas
- Use maneuvers to accentuate murmurs:
  - Inspiration (increases right-sided murmurs)
  - Expiration (increases left-sided murmurs)
  - Valsalva maneuver (affects most murmurs)
  - Exercise (can intensify murmurs)

Understanding the timing, configuration, and response to maneuvers helps differentiate between various systolic murmurs.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'diastolic_murmurs',
      title: 'Diastolic Murmurs',
      content: '''
# Diastolic Murmurs

Diastolic murmurs occur between S2 (second heart sound) and S1 (first heart sound of the next cycle), during ventricular relaxation. They are almost always pathological.

## Early Diastolic Murmurs
- Begin with S2 and diminish
- High-pitched, blowing, decrescendo quality
- Best heard with diaphragm of stethoscope, patient sitting forward in deep expiration
- Common causes:
  - Aortic regurgitation (left sternal border, 3rd-4th intercostal space)
  - Pulmonic regurgitation (left upper sternal border)

## Mid-Diastolic Murmurs
- Begin after S2, following opening snap (if present)
- Low-pitched, rumbling quality
- Best heard with bell of stethoscope at apex, patient in left lateral decubitus position
- Common causes:
  - Mitral stenosis
  - Tricuspid stenosis
  - Increased flow across atrioventricular valves (e.g., in ASD, VSD)
  - Atrial myxoma

## Late Diastolic (Presystolic) Murmurs
- Occur just before S1
- Represent enhanced flow during atrial contraction
- Often a crescendo in quality
- Common causes:
  - Mitral stenosis with sinus rhythm
  - Tricuspid stenosis with sinus rhythm

## Austin Flint Murmur
- Mid-diastolic rumbling at the apex
- Caused by aortic regurgitation jet interfering with mitral valve opening
- Can mimic mitral stenosis
- Distinguished by absence of opening snap and response to afterload reduction

## Auscultation Techniques
- Use the bell of the stethoscope for low-pitched diastolic murmurs
- Position the patient appropriately:
  - Left lateral decubitus position for mitral murmurs
  - Sitting forward, exhaling completely for aortic/pulmonic regurgitation murmurs
- Listen in quiet environment
- Ask patient to exercise briefly to increase heart rate if murmur is difficult to hear

Diastolic murmurs are significant findings that almost always indicate structural heart disease and require further evaluation.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'continuous_murmurs',
      title: 'Continuous Murmurs',
      content: '''
# Continuous Murmurs

Continuous murmurs begin in systole and continue through S2 into all or part of diastole. They are caused by persistent pressure gradients between two chambers or vessels throughout the cardiac cycle.

## Characteristics
- Present during both systole and diastole
- "Machinery-like" quality
- Often loudest during late systole and early diastole
- Can be confused with combined systolic and diastolic murmurs

## Common Causes

### Patent Ductus Arteriosus (PDA)
- Most common cause of continuous murmur
- Best heard in the left infraclavicular area or upper left sternal border
- Due to continuous flow from high-pressure aorta to low-pressure pulmonary artery
- Classically described as "machinery-like" or "washing machine" sound
- May become purely systolic with pulmonary hypertension

### Arteriovenous Fistula
- Can be congenital or acquired (e.g., traumatic, iatrogenic)
- Location of murmur depends on fistula location
- Palpable thrill often present
- Can increase with compression of the outflow vein

### Coronary Arteriovenous Fistula
- Communication between coronary artery and cardiac chamber/vessel
- Usually heard at lower left sternal border or apex
- May cause coronary steal syndrome

### Ruptured Sinus of Valsalva Aneurysm
- Sudden onset of continuous murmur
- Often associated with acute heart failure
- Usually ruptures into right atrium or ventricle
- Medical emergency requiring surgical repair

### Venous Hum
- Benign continuous murmur heard in children and young adults
- Soft, low-pitched, heard best over jugular veins
- Diminishes or disappears when supine or with jugular compression
- More prominent on the right side

### Mammary Souffle
- Continuous murmur heard over the breasts during pregnancy or lactation
- Due to increased blood flow in mammary vessels
- No clinical significance

## Differential Diagnosis
A continuous murmur must be distinguished from:
- Combined aortic stenosis and regurgitation
- Combined mitral stenosis and regurgitation
- To-and-fro murmurs that cross S2 but have a brief gap

## Auscultation Techniques
- Listen throughout the entire chest
- Note radiation pattern of the murmur
- Use maneuvers to differentiate:
  - Jugular compression (eliminates venous hum)
  - Change in position (affects venous murmurs)
  - Exercise (intensifies most pathological murmurs)

Continuous murmurs should always prompt further evaluation to determine their etiology and hemodynamic significance.
''',
      type: 'text',
    ),
  ],
),
LearningTopic(
  id: 'innocent_murmurs',
  title: 'Innocent Heart Murmurs',
  description: 'Learn to recognize and differentiate innocent heart murmurs from pathological ones.',
  resources: [
    LearningResource(
      id: 'innocent_murmurs_intro',
      title: 'Introduction to Innocent Murmurs',
      content: '''
# Introduction to Innocent Murmurs

Innocent (or functional) heart murmurs are common, benign sounds produced by blood flowing through normal cardiac structures. They occur in up to 80% of children and 10% of adults.

## General Characteristics of Innocent Murmurs
- Usually grade I-II/VI in intensity
- Systolic in timing
- No associated abnormal heart sounds or clicks
- No radiation to other areas
- Variable with position or respiration
- No associated symptoms or abnormal cardiac exam findings
- No significant personal or family cardiac history

## Clinical Significance
- Represent normal flow physiology rather than structural abnormalities
- Do not require treatment
- Do not increase risk of cardiovascular disease
- Important to differentiate from pathological murmurs to avoid unnecessary testing and parental anxiety

## When to Suspect an Innocent Murmur
- Asymptomatic patient
- Normal growth and development
- Normal cardiac examination except for the murmur
- Normal ECG and chest X-ray (if obtained)
- Murmur has typical features of an innocent murmur

## When to Suspect a Pathological Murmur
- Symptoms (exercise intolerance, syncope, chest pain)
- Abnormal cardiac examination findings (heaves, thrills, abnormal heart sounds)
- Diastolic timing
- Grade III or louder
- Loud, harsh quality
- Associated with a pathological extra heart sound
- Family history of congenital heart disease

Recognizing innocent murmurs is important to avoid unnecessary referrals, testing, and anxiety, while still ensuring that potentially significant cardiac conditions are not missed.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'innocent_murmur_types',
      title: 'Types of Innocent Murmurs',
      content: '''
# Types of Innocent Murmurs

Several distinct types of innocent murmurs have been characterized, each with specific features and age-related prevalence.

## Still's Murmur (Vibratory Murmur)
- Most common innocent murmur in children (ages 3-7 years)
- Musical, vibratory, or twanging quality
- Medium pitch, best heard with stethoscope diaphragm
- Heard best at lower left sternal border or between apex and left sternal border
- Grade I-II/VI intensity
- Early to mid-systolic timing
- Louder when supine, softer when standing
- Enhanced by fever, anxiety, or exercise

## Pulmonary Flow Murmur
- Common in children and adolescents
- Soft, blowing quality
- Heard best at upper left sternal border (pulmonary area)
- Grade I-II/VI intensity
- Early to mid-systolic timing
- May increase with inspiration
- More common in states of increased cardiac output (fever, anemia, pregnancy)

## Venous Hum
- Common in children ages 3-6 years
- Continuous, soft, low-pitched, humming quality
- Heard best above clavicles, especially on right side
- Decreases or disappears when supine or with gentle jugular vein compression
- Due to venous return from head to superior vena cava

## Physiologic Peripheral Pulmonary Stenosis Murmur
- Common in newborns and infants (up to 3 months)
- Soft, medium-pitched, ejection murmur
- Heard at upper left sternal border with radiation to back, axillae, and pulmonary areas
- Grade I-II/VI intensity
- Resolves spontaneously by 3-6 months of age
- Due to normal transition from fetal to neonatal circulation

## Mammary Souffle
- Occurs during late pregnancy and lactation
- Soft, continuous murmur
- Heard over breasts
- Due to increased mammary blood flow
- Disappears after cessation of breast-feeding

## Supraclavicular Arterial Bruit
- Common in children and young adults
- Soft, harsh systolic murmur
- Heard above clavicles
- Due to turbulent flow in brachiocephalic vessels
- Usually bilateral but louder on right
- May disappear with hyperextension of shoulders

## Carotid Bruit
- Increases with age, common in elderly
- Soft, systolic murmur over carotid arteries
- May indicate carotid stenosis in adults >50 years
- Consider vascular evaluation in older adults

Understanding these distinct types of innocent murmurs helps clinicians confidently differentiate them from pathological murmurs, reducing unnecessary referrals and investigations.
''',
      type: 'text',
    ),
  ],
),
LearningTopic(
  id: 'congenital_murmurs',
  title: 'Murmurs in Congenital Heart Disease',
  description: 'Learn about the characteristic heart murmurs associated with common congenital heart defects.',
  resources: [
    LearningResource(
      id: 'acyanotic_chd',
      title: 'Murmurs in Acyanotic Congenital Heart Disease',
      content: '''
# Murmurs in Acyanotic Congenital Heart Disease

Acyanotic congenital heart defects are those that do not typically cause cyanosis (bluish discoloration of the skin) because they do not result in significant right-to-left shunting of deoxygenated blood.

## Atrial Septal Defect (ASD)
- **Systolic murmur**: Soft, mid-systolic ejection murmur at upper left sternal border
  - Due to increased flow across pulmonary valve
  - Grade I-III/VI intensity
- **Diastolic murmur**: May have tricuspid flow rumble at lower left sternal border
- **Associated findings**:
  - Fixed split of S2 (hallmark finding)
  - Right ventricular heave
  - Right bundle branch block on ECG

## Ventricular Septal Defect (VSD)
- **Murmur character**: Harsh, holosystolic (pansystolic) murmur
- **Location**: Lower left sternal border
- **Intensity**: Variable depending on size (small: loud; large: may be quieter)
- **Radiation**: May radiate throughout precordium
- **Associated findings**:
  - Thrill may be present
  - Hyperactive precordium
  - Heart failure signs in large defects

## Patent Ductus Arteriosus (PDA)
- **Murmur character**: Continuous "machinery" murmur
- **Location**: Left infraclavicular area, extending to upper left sternal border
- **Timing**: Continues through S2, loudest during late systole/early diastole
- **Associated findings**:
  - Bounding pulses
  - Wide pulse pressure
  - Hyperactive precordium

## Pulmonary Stenosis
- **Murmur character**: Harsh, crescendo-decrescendo ejection murmur
- **Location**: Upper left sternal border (pulmonary area)
- **Timing**: Mid-systolic
- **Radiation**: May radiate to back, left shoulder, or neck
- **Associated findings**:
  - Ejection click often present (decreases with inspiration)
  - S2 widely split if severe
  - Right ventricular heave

## Aortic Stenosis
- **Murmur character**: Harsh, crescendo-decrescendo ejection murmur
- **Location**: Upper right sternal border (aortic area)
- **Timing**: Mid-systolic
- **Radiation**: To carotids, suprasternal notch, right shoulder
- **Associated findings**:
  - Ejection click may be present (does not vary with respiration)
  - Thrill in suprasternal notch or carotids
  - Decreased or delayed carotid upstrokes if severe

## Coarctation of the Aorta
- **Murmur character**: Harsh systolic ejection murmur
- **Location**: Left interscapular area of the back
- **Timing**: Systolic
- **Associated findings**:
  - Decreased or delayed femoral pulses
  - Upper extremity hypertension
  - Systolic pressure gradient between arms and legs
  - Collateral vessel murmurs may be heard

## Auscultation Techniques
- Compare murmur intensity in different positions
- Note response to respiration
- Listen over the back for transmitted murmurs
- Palpate peripheral pulses
- Correlate with other physical exam findings

Understanding these characteristic murmurs helps in the early detection and appropriate management of congenital heart defects.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'cyanotic_chd',
      title: 'Murmurs in Cyanotic Congenital Heart Disease',
      content: '''
# Murmurs in Cyanotic Congenital Heart Disease

Cyanotic congenital heart defects cause decreased oxygen saturation of arterial blood, resulting in cyanosis (bluish discoloration of the skin and mucous membranes).

## Tetralogy of Fallot
- **Murmur character**: Harsh systolic ejection murmur
- **Location**: Left sternal border
- **Intensity**: Inversely related to severity (murmur decreases during "tet spells")
- **Associated findings**:
  - Single S2 (aortic valve closure only)
  - Right ventricular heave
  - Cyanosis, worse with crying or exertion
  - Squatting position improves murmur and cyanosis
  - Boot-shaped heart on chest X-ray

## Transposition of the Great Arteries (TGA)
- **Murmur**: Often minimal or absent unless associated with VSD or pulmonary stenosis
- **Associated findings**:
  - Early cyanosis (within hours of birth)
  - Single S2
  - Heart failure signs in the absence of mixing defects
  - Egg-shaped heart on chest X-ray

## Truncus Arteriosus
- **Murmur character**: Harsh systolic ejection murmur
- **Location**: Mid-sternal to upper sternal border
- **Associated findings**:
  - Single S2
  - Early diastolic murmur of truncal valve regurgitation may be present
  - Heart failure signs
  - Cyanosis (variable)

## Total Anomalous Pulmonary Venous Return (TAPVR)
- **Obstruction absent**: Soft systolic murmur at upper left sternal border
- **Obstruction present**: Few cardiac findings; primarily respiratory distress
- **Associated findings**:
  - Fixed split S2
  - Right ventricular heave
  - Snowman appearance on chest X-ray (supracardiac type)

## Tricuspid Atresia
- **Murmur**: Depends on associated defects
- **Common findings**:
  - Holosystolic murmur of VSD (usually present)
  - Increased S2 intensity
  - Cyanosis from birth
  - Left ventricular impulse dominance

## Ebstein's Anomaly
- **Murmur character**: Multiple murmurs possible:
  - Holosystolic murmur of tricuspid regurgitation
  - Diastolic murmur due to increased flow across the tricuspid valve
- **Associated findings**:
  - Widely split S1
  - Triple or quadruple rhythm
  - Cyanosis (variable)
  - Right-sided heart failure
  - Massively enlarged heart on chest X-ray ("wall-to-wall" heart)

## Hypoplastic Left Heart Syndrome
- **Murmur**: Often minimal or absent
- **Associated findings**:
  - Single S2
  - Rapid respiratory rate
  - Poor perfusion
  - Heart failure in first days of life
  - Normal or slightly enlarged heart on chest X-ray

## Auscultation Tips
- Examine in quiet, warm environment
- Auscultate before the infant becomes agitated
- Use appropriate size stethoscope
- Listen in sequence over all cardiac areas
- Correlate with oxygen saturation measurements
- Note changes with calming, feeding, or position changes

In cyanotic congenital heart disease, the character of the murmur alone is often insufficient for diagnosis. The overall clinical picture, including degree of cyanosis, presence of heart failure, chest X-ray findings, and ECG, must be considered for accurate diagnosis and prompt intervention.
''',
      type: 'text',
    ),
  ],
),
LearningTopic(
  id: 'valvular_murmurs',
  title: 'Murmurs in Valvular Heart Disease',
  description: 'Learn about the characteristic murmurs of acquired valvular heart diseases.',
  resources: [
    LearningResource(
      id: 'mitral_valve_murmurs',
      title: 'Mitral Valve Murmurs',
      content: '''
# Mitral Valve Murmurs

The mitral valve controls blood flow between the left atrium and left ventricle. Disorders of this valve produce characteristic murmurs that help in clinical diagnosis.

## Mitral Stenosis
- **Murmur character**: Low-pitched, rumbling, diastolic murmur
- **Location**: Apex (best heard with bell of stethoscope)
- **Timing**: Mid to late diastolic, often with presystolic accentuation (if in sinus rhythm)
- **Intensity**: Grade I-IV/VI
- **Patient position**: Left lateral decubitus position
- **Associated findings**:
  - Opening snap after S2 (the interval shortens with increasing severity)
  - Loud S1
  - Signs of left atrial enlargement
  - Pulmonary hypertension in advanced cases

## Mitral Regurgitation
- **Murmur character**: High-pitched, blowing, holosystolic murmur
- **Location**: Apex
- **Radiation**: To left axilla, left scapula
- **Intensity**: Grade I-VI/VI
- **Patient position**: Left lateral decubitus position
- **Associated findings**:
  - Soft S1
  - Displaced apical impulse
  - S3 gallop in significant MR
  - Signs of pulmonary congestion in severe cases

## Mitral Valve Prolapse
- **Murmur character**: Mid to late systolic, high-pitched
- **Location**: Apex
- **Timing**: Often preceded by a mid-systolic click
- **Intensity**: Variable, often Grade I-III/VI
- **Dynamic changes**:
  - Standing or Valsalva: Click and murmur move earlier in systole
  - Squatting: Click and murmur move later in systole
- **Associated findings**:
  - Multiple clicks may be present
  - Usually benign but can lead to significant MR
  - More common in young women

## Differential Diagnosis
- Mitral stenosis vs. Austin Flint murmur (due to aortic regurgitation)
- Mitral regurgitation vs. VSD or tricuspid regurgitation
- Mitral valve prolapse vs. innocent flow murmur

## Auscultation Techniques
- Use the bell of the stethoscope for mitral stenosis
- Position in left lateral decubitus for optimal mitral valve assessment
- Perform maneuvers to accentuate subtle findings:
  - Exercise: Increases heart rate and cardiac output
  - Handgrip: Increases afterload
  - Valsalva: Decreases venous return
  - Inspiration/expiration: Affects chamber filling

## Clinical Significance
- Chronic mitral regurgitation may be well-tolerated for years
- Acute severe MR is a medical emergency
- Mitral stenosis progresses slowly but eventually leads to pulmonary hypertension
- Prophylactic antibiotics no longer routinely recommended for most valve lesions
- Anticoagulation often needed for mitral stenosis due to risk of atrial fibrillation

Understanding these murmurs helps clinicians diagnose mitral valve disorders accurately, assess their severity, and make appropriate management decisions.
''',
      type: 'text',
    ),
    LearningResource(
      id: 'aortic_valve_murmurs',
      title: 'Aortic Valve Murmurs',
      content: '''
# Aortic Valve Murmurs

The aortic valve controls blood flow from the left ventricle to the aorta. Disorders affecting this valve produce characteristic murmurs that are important for clinical diagnosis.

## Aortic Stenosis
- **Murmur character**: Harsh, crescendo-decrescendo, "diamond-shaped" ejection murmur
- **Location**: Right upper sternal border (2nd right intercostal space)
- **Radiation**: To carotid arteries, apex (Gallavardin phenomenon), and suprasternal notch
- **Timing**: Mid-systolic
- **Intensity**: Grade I-VI/VI (intensity not always correlating with severity)
- **Associated findings**:
  - Decreased carotid pulses with slow upstroke (pulsus parvus et tardus)
  - Sustained apical impulse
  - S4 gallop in severe AS
  - Ejection click with bicuspid valve (disappears with severe stenosis)
  - Paradoxical split S2 in severe cases
  - Narrowed pulse pressure

## Aortic Regurgitation
- **Murmur character**: High-pitched, blowing, decrescendo diastolic murmur
- **Location**: Left sternal border (3rd-4th intercostal space)
- **Timing**: Early diastolic, begins immediately after S2
- **Intensity**: Grade I-IV/VI (often quite soft)
- **Patient position**: Sitting forward, deep exhalation
- **Associated findings**:
  - Wide pulse pressure
  - Bounding peripheral pulses
  - Multiple peripheral signs: 
    - de Musset's sign (head bobbing)
    - Quincke's pulse (capillary pulsations)
    - Duroziez's sign (femoral double murmur)
    - Corrigan's pulse (water-hammer pulse)
  - Austin Flint murmur (apical mid-diastolic rumble)

## Bicuspid Aortic Valve
- **Murmur character**: Systolic ejection murmur, similar to mild aortic stenosis
- **Location**: Right upper sternal border
- **Timing**: Systolic ejection, often with ejection click
- **Clinical significance**:
  - Most common congenital cardiac anomaly (1-2% of population)
  - Prone to progressive stenosis, regurgitation, and aortic dilation
  - Requires surveillance even when asymptomatic

## Aortic Sclerosis vs. Stenosis
- **Aortic sclerosis**:
  - Degenerative valve thickening without significant obstruction
  - Systolic ejection murmur similar to mild AS
  - Normal carotid upstrokes
  - No significant gradient across valve
  - Common in elderly (25-30% over age 65)
- **Aortic stenosis**:
  - Progressive narrowing of valve orifice
  - Pressure gradient across valve
  - Symptoms when severe: syncope, angina, heart failure

## Auscultation Techniques
- Use the diaphragm of the stethoscope
- Have patient sit forward and exhale fully for aortic regurgitation
- Listen at right sternal border, suprasternal notch, and carotids for aortic stenosis
- Palpate carotid upstroke while auscultating
- Correlation with peripheral signs is essential

## Clinical Significance
- Severe aortic stenosis is a surgical disease once symptomatic
- Acute severe aortic regurgitation is a medical emergency
- Chronic aortic regurgitation may be well-tolerated for years
- Regular follow-up with echocardiography recommended for moderate disease

Understanding these characteristic murmurs is essential for early detection, monitoring, and appropriate timing of intervention in aortic valve disease.
''',
      type: 'text',
    ),
  ],
),
  ];
  
}

  /// Get default heart murmurs
  List<HeartMurmur> _getDefaultHeartMurmurs() {
 return [
    HeartMurmur(
      id: 'aortic_stenosis',
      name: 'Aortic Stenosis',
      description: 'Systolic ejection murmur due to narrowing of the aortic valve opening, resulting in obstruction of left ventricular outflow.',
      position: 'Right 2nd intercostal space (aortic area)',
      timing: 'Systolic',
      quality: 'Harsh, crescendo-decrescendo (diamond-shaped)',
      grade: 'I-VI (intensity correlates poorly with severity)',
      audioUrl: 'audio/heart_murmurs/aortic_stenosis.mp3',
      clinicalImplications: [
        'Left ventricular hypertrophy',
        'Angina pectoris',
        'Syncope (especially with exertion)',
        'Heart failure',
        'Sudden cardiac death',
        'Calcific emboli'
      ],
      imageUrl: 'images/heart_murmurs/aortic_stenosis.png',
    ),
    HeartMurmur(
      id: 'mitral_regurgitation',
      name: 'Mitral Regurgitation',
      description: 'Holosystolic murmur caused by backflow of blood from the left ventricle to the left atrium due to incomplete closure of the mitral valve.',
      position: 'Apex (5th intercostal space, midclavicular line)',
      timing: 'Holosystolic (pansystolic)',
      quality: 'Blowing, high-pitched',
      grade: 'I-VI',
      audioUrl: 'audio/heart_murmurs/mitral_regurgitation.mp3',
      clinicalImplications: [
        'Left atrial enlargement',
        'Left ventricular dilatation',
        'Pulmonary hypertension',
        'Atrial fibrillation',
        'Heart failure',
        'Pulmonary edema'
      ],
      imageUrl: 'images/heart_murmurs/mitral_regurgitation.png',
    ),
    HeartMurmur(
      id: 'mitral_valve_prolapse',
      name: 'Mitral Valve Prolapse',
      description: 'Mid-to-late systolic murmur preceded by a mid-systolic click, caused by prolapse of mitral valve leaflets into the left atrium.',
      position: 'Apex (5th intercostal space, midclavicular line)',
      timing: 'Mid-to-late systolic, preceded by mid-systolic click',
      quality: 'High-pitched, may be musical or whooping',
      grade: 'I-III (variable)',
      audioUrl: 'audio/heart_murmurs/mitral_valve_prolapse.mp3',
      clinicalImplications: [
        'Progressive mitral regurgitation',
        'Chordal rupture',
        'Atrial arrhythmias',
        'Increased risk of endocarditis',
        'Rare ventricular arrhythmias'
      ],
      imageUrl: 'images/heart_murmurs/mitral_valve_prolapse.png',
    ),
    HeartMurmur(
      id: 'ventricular_septal_defect',
      name: 'Ventricular Septal Defect (VSD)',
      description: 'Holosystolic murmur caused by blood flow from the left ventricle to the right ventricle through a defect in the interventricular septum.',
      position: 'Left lower sternal border (3rd-4th intercostal space)',
      timing: 'Holosystolic (pansystolic)',
      quality: 'Harsh, may have thrill',
      grade: 'III-VI (often loud)',
      audioUrl: 'audio/heart_murmurs/vsd.mp3',
      clinicalImplications: [
        'Right ventricular hypertrophy',
        'Pulmonary hypertension',
        'Right heart failure',
        'Eisenmenger syndrome (in unrepaired large defects)',
        'Infective endocarditis risk'
      ],
      imageUrl: 'images/heart_murmurs/vsd.png',
    ),
    HeartMurmur(
      id: 'patent_ductus_arteriosus',
      name: 'Patent Ductus Arteriosus (PDA)',
      description: 'Continuous "machinery" murmur caused by persistent connection between the aorta and pulmonary artery.',
      position: 'Left infraclavicular area (2nd intercostal space)',
      timing: 'Continuous (throughout systole and diastole)',
      quality: 'Machinery-like, "washing machine" sound',
      grade: 'I-IV',
      audioUrl: 'audio/heart_murmurs/pda.mp3',
      clinicalImplications: [
        'Left heart volume overload',
        'Pulmonary hypertension',
        'Congestive heart failure',
        'Eisenmenger syndrome (if large and untreated)',
        'Infective endocarditis risk'
      ],
      imageUrl: 'images/heart_murmurs/pda.png',
    ),
    HeartMurmur(
      id: 'mitral_stenosis',
      name: 'Mitral Stenosis',
      description: 'Diastolic rumbling murmur caused by narrowing of the mitral valve opening, restricting blood flow from the left atrium to the left ventricle.',
      position: 'Apex (5th intercostal space, midclavicular line), with patient in left lateral position',
      timing: 'Mid to late diastolic, often with presystolic accentuation',
      quality: 'Low-pitched, rumbling (use bell of stethoscope)',
      grade: 'I-IV',
      audioUrl: 'audio/heart_murmurs/mitral_stenosis.mp3',
      clinicalImplications: [
        'Left atrial enlargement',
        'Pulmonary hypertension',
        'Atrial fibrillation',
        'Right heart failure',
        'Pulmonary edema',
        'Systemic embolism'
      ],
      imageUrl: 'images/heart_murmurs/mitral_stenosis.png',
    ),
    HeartMurmur(
      id: 'aortic_regurgitation',
      name: 'Aortic Regurgitation',
      description: 'Early diastolic, decrescendo murmur caused by backflow of blood from the aorta to the left ventricle due to incomplete closure of the aortic valve.',
      position: 'Left sternal border, 3rd/4th intercostal space (Erb\'s point)',
      timing: 'Early diastolic, decrescendo',
      quality: 'High-pitched, blowing, "whooshing"',
      grade: 'I-IV',
      audioUrl: 'audio/heart_murmurs/aortic_regurgitation.mp3',
      clinicalImplications: [
        'Left ventricular dilatation',
        'Volume overload',
        'Heart failure',
        'Wide pulse pressure',
        'Water-hammer pulse (Corrigan\'s pulse)'
      ],
      imageUrl: 'images/heart_murmurs/aortic_regurgitation.png',
    ),
    HeartMurmur(
      id: 'tricuspid_regurgitation',
      name: 'Tricuspid Regurgitation',
      description: 'Holosystolic murmur caused by backflow of blood from the right ventricle to the right atrium due to incomplete closure of the tricuspid valve.',
      position: 'Lower left sternal border or xiphoid area',
      timing: 'Holosystolic (pansystolic)',
      quality: 'Soft, blowing, high-pitched',
      grade: 'I-IV (often soft)',
      audioUrl: 'audio/heart_murmurs/tricuspid_regurgitation.mp3',
      clinicalImplications: [
        'Right atrial enlargement',
        'Jugular venous distention',
        'Hepatomegaly',
        'Peripheral edema',
        'Ascites',
        'Often secondary to pulmonary hypertension'
      ],
      imageUrl: 'images/heart_murmurs/tricuspid_regurgitation.png',
    ),
    HeartMurmur(
      id: 'pulmonary_stenosis',
      name: 'Pulmonary Stenosis',
      description: 'Systolic ejection murmur caused by narrowing of the pulmonary valve, obstructing right ventricular outflow.',
      position: 'Left upper sternal border (2nd intercostal space, pulmonic area)',
      timing: 'Systolic ejection (crescendo-decrescendo)',
      quality: 'Harsh, may have thrill',
      grade: 'I-VI',
      audioUrl: 'audio/heart_murmurs/pulmonary_stenosis.mp3',
      clinicalImplications: [
        'Right ventricular hypertrophy',
        'Right ventricular failure',
        'Cyanosis (if severe or with right-to-left shunt)',
        'Syncope with exertion'
      ],
      imageUrl: 'images/heart_murmurs/pulmonary_stenosis.png',
    ),
    HeartMurmur(
      id: 'atrial_septal_defect',
      name: 'Atrial Septal Defect (ASD)',
      description: 'Systolic ejection murmur at the pulmonic area due to increased flow across the pulmonary valve, with fixed splitting of S2.',
      position: 'Left upper sternal border (2nd-3rd intercostal space)',
      timing: 'Systolic ejection, with fixed split S2',
      quality: 'Medium-pitched, "swishing"',
      grade: 'I-III',
      audioUrl: 'audio/heart_murmurs/atrial_septal_defect.mp3',
      clinicalImplications: [
        'Right ventricular volume overload',
        'Right atrial enlargement',
        'Pulmonary hypertension (late)',
        'Atrial arrhythmias',
        'Paradoxical embolism'
      ],
      imageUrl: 'images/heart_murmurs/atrial_septal_defect.png',
    ),
    HeartMurmur(
      id: 'hypertrophic_cardiomyopathy',
      name: 'Hypertrophic Cardiomyopathy (HOCM)',
      description: 'Harsh systolic murmur that increases with Valsalva and standing, caused by dynamic obstruction of the left ventricular outflow tract.',
      position: 'Left lower sternal border and apex',
      timing: 'Systolic, crescendo-decrescendo',
      quality: 'Harsh, dynamic (varies with maneuvers)',
      grade: 'II-V (variable)',
      audioUrl: 'audio/heart_murmurs/hocm.mp3',
      clinicalImplications: [
        'Left ventricular hypertrophy',
        'Diastolic dysfunction',
        'Syncope',
        'Chest pain',
        'Sudden cardiac death',
        'Arrhythmias'
      ],
      imageUrl: 'images/heart_murmurs/hocm.png',
    ),
    HeartMurmur(
      id: 'aortic_sclerosis',
      name: 'Aortic Sclerosis',
      description: 'Systolic ejection murmur similar to aortic stenosis but without significant gradient, caused by age-related valve thickening and calcification.',
      position: 'Right upper sternal border (2nd intercostal space, aortic area)',
      timing: 'Early to mid-systolic',
      quality: 'Soft to moderate, "sandpaper-like"',
      grade: 'I-III',
      audioUrl: 'audio/heart_murmurs/aortic_sclerosis.mp3',
      clinicalImplications: [
        'Usually hemodynamically insignificant',
        'Associated with atherosclerotic disease',
        'May progress to aortic stenosis',
        'Independent risk factor for cardiovascular events'
      ],
      imageUrl: 'images/heart_murmurs/aortic_sclerosis.png',
    ),
    HeartMurmur(
      id: 'innocent_murmur',
      name: 'Innocent (Physiological) Murmur',
      description: 'Benign murmur without underlying structural heart disease, common in children and young adults.',
      position: 'Left lower sternal border or upper left sternal border',
      timing: 'Early to mid-systolic',
      quality: 'Soft, musical, vibratory (Still\'s murmur) or gently blowing',
      grade: 'I-II (never loud)',
      audioUrl: 'audio/heart_murmurs/innocent_murmur.mp3',
      clinicalImplications: [
        'No structural heart disease',
        'No clinical significance',
        'No activity restrictions needed',
        'Often disappears when sitting up or standing',
        'May vary with respiration or position'
      ],
      imageUrl: 'images/heart_murmurs/innocent_murmur.png',
    ),
  ];
}
      
  /// Get default quizzes
  List<Quiz> _getDefaultQuizzes() {
  return [
    Quiz(
      id: 'ecg_basics_quiz',
      title: 'ECG Basics Quiz',
      description: 'Test your knowledge of basic ECG interpretation.',
      category: 'ECG',
      difficulty: 'Easy',
      questions: [
        QuizQuestion(
          id: 'ecg_q1',
          question: 'What does the P wave represent in an ECG?',
          options: [
            'Ventricular depolarization',
            'Atrial depolarization',
            'Ventricular repolarization',
            'Atrial repolarization'
          ],
          correctAnswerIndex: 1,
          explanation: 'The P wave represents atrial depolarization (contraction of the atria).',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q2',
          question: 'What does the QRS complex represent in an ECG?',
          options: [
            'Atrial depolarization',
            'Ventricular depolarization',
            'Atrial repolarization',
            'Ventricular repolarization'
          ],
          correctAnswerIndex: 1,
          explanation: 'The QRS complex represents ventricular depolarization (contraction of the ventricles).',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q3',
          question: 'What is the normal duration of the PR interval?',
          options: [
            '0.04-0.08 seconds',
            '0.12-0.20 seconds',
            '0.20-0.40 seconds',
            '0.40-0.60 seconds'
          ],
          correctAnswerIndex: 1,
          explanation: 'The normal PR interval is 0.12-0.20 seconds, representing the time for electrical impulse to travel from the atria to the ventricles.',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q4',
          question: 'Which of the following ECG abnormalities is associated with a myocardial infarction (heart attack)?',
          options: [
            'Tall T waves',
            'Prolonged PR interval',
            'ST segment elevation',
            'U waves'
          ],
          correctAnswerIndex: 2,
          explanation: 'ST segment elevation is a classic ECG finding in myocardial infarction, indicating acute injury to the heart muscle.',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q5',
          question: 'What is the normal heart rate range for adults at rest?',
          options: [
            '40-60 beats per minute',
            '60-100 beats per minute',
            '100-120 beats per minute',
            '120-150 beats per minute'
          ],
          correctAnswerIndex: 1,
          explanation: 'The normal resting heart rate for adults is 60-100 beats per minute.',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q6',
          question: 'Which of the following is NOT a feature of right bundle branch block (RBBB)?',
          options: [
            'QRS duration ≥ 120 ms',
            'RSR\' pattern in V1',
            'Wide S wave in leads I and V6',
            'Left axis deviation'
          ],
          correctAnswerIndex: 3,
          explanation: 'Left axis deviation is not a typical feature of right bundle branch block. RBBB is characterized by QRS duration ≥ 120 ms, RSR\' pattern in V1, and wide S waves in leads I and V6.',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q7',
          question: 'What does the T wave represent on an ECG?',
          options: [
            'Atrial depolarization',
            'Ventricular depolarization',
            'Atrial repolarization',
            'Ventricular repolarization'
          ],
          correctAnswerIndex: 3,
          explanation: 'The T wave represents ventricular repolarization (relaxation of the ventricles).',
          category: 'ECG',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'ecg_q8',
          question: 'Which lead is best for examining the inferior wall of the left ventricle?',
          options: [
            'Lead I',
            'Lead aVL',
            'Lead II',
            'Lead V1'
          ],
          correctAnswerIndex: 2,
          explanation: 'Lead II (along with leads III and aVF) are the inferior leads that best examine the inferior wall of the left ventricle.',
          category: 'ECG',
          difficulty: 'Easy',
        ),
      ],
      timeLimit: 480,
    ),
    Quiz(
      id: 'ecg_arrhythmias_quiz',
      title: 'ECG Arrhythmias Quiz',
      description: 'Test your knowledge of cardiac arrhythmias on ECG.',
      category: 'ECG',
      difficulty: 'Medium',
      questions: [
        QuizQuestion(
          id: 'arrhythmia_q1',
          question: 'Which of the following is the hallmark ECG finding in atrial fibrillation?',
          options: [
            'Regular rhythm with absent P waves',
            'Irregular rhythm with absent P waves',
            'Regular rhythm with saw-tooth pattern',
            'Regular rhythm with retrograde P waves'
          ],
          correctAnswerIndex: 1,
          explanation: 'Atrial fibrillation is characterized by an irregular rhythm with absent P waves, replaced by irregular fibrillatory waves.',
          category: 'ECG',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'arrhythmia_q2',
          question: 'What are the characteristics of ventricular tachycardia on ECG?',
          options: [
            'Regular, narrow QRS complexes at a rate >100 bpm',
            'Regular, wide QRS complexes at a rate >100 bpm with AV dissociation',
            'Irregular, wide QRS complexes with visible P waves',
            'Narrow QRS complexes with a rate of 70-100 bpm'
          ],
          correctAnswerIndex: 1,
          explanation: 'Ventricular tachycardia typically presents with regular, wide QRS complexes (>120 ms) at a rate greater than 100 bpm, often with AV dissociation (P waves unrelated to QRS complexes).',
          category: 'ECG',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'arrhythmia_q3',
          question: 'In second-degree AV block Mobitz type I (Wenckebach), what happens to the PR interval?',
          options: [
            'It remains constant',
            'It progressively shortens until a P wave is dropped',
            'It progressively lengthens until a P wave is dropped',
            'It alternates between short and long'
          ],
          correctAnswerIndex: 2,
          explanation: 'In second-degree AV block Mobitz type I (Wenckebach), the PR interval progressively lengthens until a P wave is not conducted (dropped beat), after which the cycle repeats.',
          category: 'ECG',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'arrhythmia_q4',
          question: 'What is the most likely diagnosis for a regular, narrow-complex tachycardia at 150 bpm with sudden onset and termination?',
          options: [
            'Sinus tachycardia',
            'Atrial fibrillation',
            'Ventricular tachycardia',
            'Supraventricular tachycardia (AVNRT or AVRT)'
          ],
          correctAnswerIndex: 3,
          explanation: 'A regular, narrow-complex tachycardia at 150 bpm with sudden onset and termination is most characteristic of supraventricular tachycardia (SVT), either AV nodal reentrant tachycardia (AVNRT) or AV reentrant tachycardia (AVRT).',
          category: 'ECG',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'arrhythmia_q5',
          question: 'Which of the following best describes third-degree (complete) AV block?',
          options: [
            'Some P waves are not followed by QRS complexes',
            'PR interval varies but all P waves are conducted',
            'P waves and QRS complexes are completely dissociated',
            'PR interval is fixed but prolonged'
          ],
          correctAnswerIndex: 2,
          explanation: 'Third-degree (complete) AV block is characterized by complete dissociation between P waves and QRS complexes, meaning the atria and ventricles are beating independently of each other.',
          category: 'ECG',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'arrhythmia_q6',
          question: 'Which of the following arrhythmias is most commonly associated with digitalis toxicity?',
          options: [
            'Atrial flutter',
            'Ventricular fibrillation',
            'Atrial tachycardia with block',
            'Sinus tachycardia'
          ],
          correctAnswerIndex: 2,
          explanation: 'Atrial tachycardia with block (atrial tachycardia with 2:1 or higher degree AV block) is classically associated with digitalis toxicity, along with other findings such as enhanced automaticity and bidirectional ventricular tachycardia.',
          category: 'ECG',
          difficulty: 'Medium',
        ),
      ],
      timeLimit: 360,
    ),
    Quiz(
      id: 'ecg_mi_quiz',
      title: 'Myocardial Infarction ECG Patterns',
      description: 'Test your knowledge of ECG changes in various types of myocardial infarction.',
      category: 'ECG',
      difficulty: 'Hard',
      questions: [
        QuizQuestion(
          id: 'mi_q1',
          question: 'ST elevation in leads V1-V4 most likely indicates infarction in which territory?',
          options: [
            'Inferior wall',
            'Lateral wall',
            'Anterior wall',
            'Posterior wall'
          ],
          correctAnswerIndex: 2,
          explanation: 'ST elevation in leads V1-V4 indicates anterior wall myocardial infarction, typically due to occlusion of the left anterior descending (LAD) artery.',
          category: 'ECG',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'mi_q2',
          question: 'ST elevation in leads II, III, and aVF with ST depression in leads I and aVL indicates infarction in which territory?',
          options: [
            'Anterior wall',
            'Inferior wall',
            'Lateral wall',
            'Septal wall'
          ],
          correctAnswerIndex: 1,
          explanation: 'ST elevation in leads II, III, and aVF indicates inferior wall myocardial infarction, typically due to occlusion of the right coronary artery (RCA) or left circumflex artery. The reciprocal ST depression in leads I and aVL is a common finding.',
          category: 'ECG',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'mi_q3',
          question: 'Which ECG finding is most specific for acute posterior wall myocardial infarction?',
          options: [
            'ST elevation in leads V1-V3',
            'ST elevation in leads II, III, aVF',
            'ST depression and tall R waves in leads V1-V3',
            'ST elevation in leads I, aVL, V5, V6'
          ],
          correctAnswerIndex: 2,
          explanation: 'Posterior wall myocardial infarction is characterized by ST depression and tall R waves in leads V1-V3, which represent reciprocal changes to the posterior wall. This is because standard leads do not directly face the posterior wall of the left ventricle.',
          category: 'ECG',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'mi_q4',
          question: 'ST elevation in leads V1-V4 with right bundle branch block and ST elevation in lead aVR is concerning for:',
          options: [
            'Isolated anterior wall MI',
            'Right ventricular infarction',
            'Left main coronary artery occlusion',
            'Inferolateral MI'
          ],
          correctAnswerIndex: 2,
          explanation: 'ST elevation in lead aVR, especially when greater than or equal to the ST elevation in lead V1, along with diffuse ST depression and/or ST elevation in anterior leads is concerning for left main coronary artery occlusion, which is a medical emergency with high mortality.',
          category: 'ECG',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'mi_q5',
          question: 'Which of the following ECG changes is typically seen earliest in the course of an acute myocardial infarction?',
          options: [
            'Pathological Q waves',
            'ST segment elevation',
            'T wave inversion',
            'Hyperacute (tall, peaked) T waves'
          ],
          correctAnswerIndex: 3,
          explanation: 'The earliest ECG change in acute myocardial infarction is often hyperacute (tall, peaked) T waves, which may appear within minutes of coronary occlusion. This is followed by ST elevation, then T wave inversion, and finally the development of pathological Q waves.',
          category: 'ECG',
          difficulty: 'Hard',
        ),
      ],
      timeLimit: 300,
    ),
    Quiz(
      id: 'heart_murmurs_quiz',
      title: 'Heart Murmur Identification',
      description: 'Test your knowledge of heart murmur identification and classification.',
      category: 'Heart Murmurs',
      difficulty: 'Medium',
      questions: [
        QuizQuestion(
          id: 'murmur_q1',
          question: 'Which heart murmur is characterized by a harsh, crescendo-decrescendo systolic ejection murmur at the right upper sternal border?',
          options: [
            'Mitral regurgitation',
            'Aortic stenosis',
            'Ventricular septal defect',
            'Patent ductus arteriosus'
          ],
          correctAnswerIndex: 1,
          explanation: 'Aortic stenosis produces a harsh, crescendo-decrescendo (diamond-shaped) systolic ejection murmur best heard at the right upper sternal border (2nd intercostal space).',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q2',
          question: 'Which auscultation position is best for hearing a mitral regurgitation murmur?',
          options: [
            'Right 2nd intercostal space',
            'Left 2nd intercostal space',
            'Left lower sternal border',
            'Apex (5th intercostal space, midclavicular line)'
          ],
          correctAnswerIndex: 3,
          explanation: 'Mitral regurgitation murmurs are best heard at the cardiac apex (5th intercostal space, midclavicular line) and often radiate to the axilla.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q3',
          question: 'Which heart murmur is continuous throughout the cardiac cycle?',
          options: [
            'Aortic stenosis',
            'Mitral stenosis',
            'Patent ductus arteriosus',
            'Tricuspid regurgitation'
          ],
          correctAnswerIndex: 2,
          explanation: 'Patent ductus arteriosus (PDA) produces a continuous "machinery" murmur that persists throughout the cardiac cycle because blood flows from the aorta to the pulmonary artery during both systole and diastole.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q4',
          question: 'What is the most common cause of a diastolic rumbling murmur at the apex?',
          options: [
            'Mitral stenosis',
            'Tricuspid stenosis',
            'Aortic regurgitation',
            'Mitral valve prolapse'
          ],
          correctAnswerIndex: 0,
          explanation: 'Mitral stenosis classically produces a mid to late diastolic rumbling murmur best heard at the apex, often requiring the patient to be in the left lateral decubitus position for optimal auscultation.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q5',
          question: 'Which heart murmur typically intensifies during inspiration?',
          options: [
            'Mitral regurgitation',
            'Aortic stenosis',
            'Tricuspid regurgitation',
            'Mitral stenosis'
          ],
          correctAnswerIndex: 2,
          explanation: 'Tricuspid regurgitation murmurs typically intensify during inspiration (Carvallo\'s sign), which is a characteristic of right-sided heart murmurs. Left-sided murmurs usually decrease or remain unchanged with inspiration.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q6',
          question: 'A holosystolic murmur at the lower left sternal border that increases with respiration is most likely:',
          options: [
            'Mitral regurgitation',
            'Aortic stenosis',
            'Tricuspid regurgitation',
            'Ventricular septal defect'
          ],
          correctAnswerIndex: 2,
          explanation: 'A holosystolic murmur at the lower left sternal border that increases with respiration (inspiration) is most consistent with tricuspid regurgitation. This respiratory variation (Carvallo\'s sign) is a key feature of right-sided murmurs.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q7',
          question: 'Which maneuver would typically make the murmur of hypertrophic cardiomyopathy (HOCM) louder?',
          options: [
            'Squatting',
            'Standing',
            'Passive leg elevation',
            'Lying flat'
          ],
          correctAnswerIndex: 1,
          explanation: 'The murmur of hypertrophic cardiomyopathy becomes louder with maneuvers that decrease ventricular volume, such as standing or the Valsalva maneuver. Squatting or passive leg elevation, which increase ventricular volume, typically decrease the murmur intensity.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'murmur_q8',
          question: 'A mid-systolic click followed by a late systolic murmur is characteristic of:',
          options: [
            'Aortic stenosis',
            'Mitral valve prolapse',
            'Ventricular septal defect',
            'Tricuspid regurgitation'
          ],
          correctAnswerIndex: 1,
          explanation: 'A mid-systolic click followed by a late systolic murmur is the classic auscultatory finding in mitral valve prolapse. The click represents the sudden tensing of the prolapsing leaflet and chordae tendineae, while the murmur represents the resulting regurgitation.',
          category: 'Heart Murmurs',
          difficulty: 'Medium',
        ),
      ],
      timeLimit: 480,
    ),
    Quiz(
      id: 'heart_murmurs_advanced_quiz',
      title: 'Advanced Heart Murmur Identification',
      description: 'Test your advanced knowledge of heart murmur identification and differentiation in complex cases.',
      category: 'Heart Murmurs',
      difficulty: 'Hard',
      questions: [
        QuizQuestion(
          id: 'adv_murmur_q1',
          question: 'A patient has a mid-diastolic rumbling murmur at the apex that becomes louder during expiration. The murmur is accompanied by an opening snap. Which valve lesion is most likely?',
          options: [
            'Mitral stenosis',
            'Tricuspid stenosis',
            'Aortic regurgitation with Austin Flint murmur',
            'Atrial myxoma'
          ],
          correctAnswerIndex: 0,
          explanation: 'A mid-diastolic rumbling murmur at the apex accompanied by an opening snap, which becomes louder during expiration, is classic for mitral stenosis. Left-sided murmurs, including mitral stenosis, typically become louder during expiration because of increased blood flow through the left side of the heart.',
          category: 'Heart Murmurs',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'adv_murmur_q2',
          question: 'A 25-year-old patient with Marfan syndrome presents with a high-pitched, early diastolic murmur at the left sternal border. Which of the following is the most likely cause?',
          options: [
            'Mitral stenosis',
            'Aortic regurgitation due to aortic root dilation',
            'Pulmonary regurgitation',
            'Tricuspid stenosis'
          ],
          correctAnswerIndex: 1,
          explanation: 'In a patient with Marfan syndrome, a high-pitched, early diastolic murmur at the left sternal border is most likely aortic regurgitation due to aortic root dilation, which is a common cardiovascular manifestation of Marfan syndrome.',
          category: 'Heart Murmurs',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'adv_murmur_q3',
          question: 'A patient with severe aortic regurgitation has a mid-diastolic rumbling murmur at the apex. This is most likely:',
          options: [
            'Concurrent mitral stenosis',
            'Austin Flint murmur',
            'Flow murmur across the tricuspid valve',
            'Carey Coombs murmur'
          ],
          correctAnswerIndex: 1,
          explanation: 'In a patient with severe aortic regurgitation, a mid-diastolic rumbling murmur at the apex is most likely an Austin Flint murmur. This is caused by the aortic regurgitant jet impinging on the anterior mitral leaflet, causing functional mitral stenosis.',
          category: 'Heart Murmurs',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'adv_murmur_q4',
          question: 'A patient with a previous myocardial infarction has a new holosystolic murmur at the apex that radiates to the axilla, with an accompanying thrill. The most likely diagnosis is:',
          options: [
            'Functional mitral regurgitation due to papillary muscle dysfunction',
            'Acute mitral regurgitation due to papillary muscle rupture',
            'Ventricular septal rupture',
            'Tricuspid regurgitation'
          ],
          correctAnswerIndex: 1,
          explanation: 'A new, loud (with thrill) holosystolic murmur at the apex radiating to the axilla in a patient with recent myocardial infarction suggests acute mitral regurgitation due to papillary muscle rupture, which is a mechanical complication of MI that typically occurs 2-7 days post-infarction.',
          category: 'Heart Murmurs',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'adv_murmur_q5',
          question: 'Which of the following is the most reliable way to differentiate the murmur of hypertrophic cardiomyopathy from the murmur of aortic stenosis?',
          options: [
            'Location of the murmur',
            'Quality of the murmur',
            'Response to Valsalva maneuver',
            'Timing during systole'
          ],
          correctAnswerIndex: 2,
          explanation: 'The most reliable way to differentiate between hypertrophic cardiomyopathy and aortic stenosis murmurs is the response to the Valsalva maneuver. The murmur of hypertrophic cardiomyopathy increases during Valsalva, while the murmur of aortic stenosis decreases or remains unchanged.',
          category: 'Heart Murmurs',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'adv_murmur_q6',
          question: 'In a patient with rheumatic heart disease, you hear a mid-diastolic rumble at the apex, a holosystolic murmur at the apex radiating to the axilla, and an early diastolic murmur at the left sternal border. What combination of valve lesions is most likely?',
          options: [
            'Mitral stenosis, tricuspid regurgitation, and aortic stenosis',
            'Mitral stenosis, mitral regurgitation, and aortic regurgitation',
            'Tricuspid stenosis, mitral regurgitation, and pulmonic regurgitation',
            'Mitral stenosis, tricuspid regurgitation, and pulmonic stenosis'
          ],
          correctAnswerIndex: 1,
          explanation: 'The combination of a mid-diastolic rumble at the apex (mitral stenosis), a holosystolic murmur at the apex radiating to the axilla (mitral regurgitation), and an early diastolic murmur at the left sternal border (aortic regurgitation) is typical of rheumatic heart disease affecting multiple valves.',
          category: 'Heart Murmurs',
          difficulty: 'Hard',
        ),
      ],
      timeLimit: 360,
    ),
    Quiz(
      id: 'pulseox_quiz',
      title: 'Pulse Oximetry Fundamentals',
      description: 'Test your knowledge of pulse oximetry and oxygen saturation.',
      category: 'PulseOx',
      difficulty: 'Easy',
      questions: [
        QuizQuestion(
          id: 'pulseox_q1',
          question: 'What is the normal range for oxygen saturation (SpO2)?',
          options: [
            '70-80%',
            '80-90%',
            '95-100%',
            '60-70%'
          ],
          correctAnswerIndex: 2,
          explanation: 'Normal oxygen saturation (SpO2) is between 95-100%. Values of 90-94% may indicate mild hypoxemia, while values below 90% indicate significant hypoxemia requiring intervention.',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'pulseox_q2',
          question: 'Which of the following can cause an artificially low SpO2 reading?',
          options: [
            'Anemia',
            'Nail polish',
            'Supplemental oxygen',
            'Hyperventilation'
          ],
          correctAnswerIndex: 1,
          explanation: 'Nail polish (especially dark colors) can interfere with the light transmission of the pulse oximeter sensor, leading to artificially low SpO2 readings. Other factors that can cause inaccurate readings include poor peripheral circulation, cold extremities, and motion artifacts.',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'pulseox_q3',
          question: 'Pulse oximeters work by measuring the absorption of which wavelengths of light?',
          options: [
            'Ultraviolet and visible light',
            'Red and infrared light',
            'Gamma rays and X-rays',
            'Radio waves and microwaves'
          ],
          correctAnswerIndex: 1,
          explanation: 'Pulse oximeters use red (660 nm) and infrared (940 nm) light to measure oxygen saturation. Oxygenated hemoglobin absorbs more infrared light and allows more red light to pass through, while deoxygenated hemoglobin absorbs more red light and allows more infrared light to pass through.',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'pulseox_q4',
          question: 'In which condition might pulse oximetry give falsely normal readings despite actual hypoxemia?',
          options: [
            'Severe anemia',
            'Carbon monoxide poisoning',
            'Methemoglobinemia',
            'All of the above'
          ],
          correctAnswerIndex: 3,
          explanation: 'Pulse oximetry can give falsely normal readings in conditions like carbon monoxide poisoning (carboxyhemoglobin is read as oxygenated hemoglobin), methemoglobinemia (readings tend toward 85% regardless of actual saturation), and severe anemia (reduced oxygen-carrying capacity despite normal saturation percentage).',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'pulseox_q5',
          question: 'Which finger is generally preferred for pulse oximetry readings in adults?',
          options: [
            'Thumb',
            'Index finger',
            'Middle finger',
            'Ring finger'
          ],
          correctAnswerIndex: 2,
          explanation: 'The middle finger is generally preferred for pulse oximetry readings in adults because it typically has the best perfusion and fit for the sensor. However, the index and ring fingers are also commonly used and may provide accurate readings.',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'pulseox_q6',
          question: 'What SpO2 level is generally considered the threshold for supplemental oxygen therapy in most adults?',
          options: [
            'Below 95%',
            'Below 92%',
            'Below 90%',
            'Below 85%'
          ],
          correctAnswerIndex: 2,
          explanation: 'In most adults, an SpO2 below 90% is generally considered the threshold for supplemental oxygen therapy. However, this may vary based on individual patient factors and specific clinical situations.',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
        QuizQuestion(
          id: 'pulseox_q7',
          question: 'Which of the following best describes the principle behind pulse oximetry?',
          options: [
            'Direct measurement of oxygen molecules in blood',
            'Measurement of oxygen pressure gradient across the alveolar-capillary membrane',
            'Differential light absorption by oxygenated and deoxygenated hemoglobin',
            'Chemical reaction between a sensor and oxygen in the bloodstream'
          ],
          correctAnswerIndex: 2,
          explanation: 'Pulse oximetry works on the principle of differential light absorption by oxygenated and deoxygenated hemoglobin. Oxygenated hemoglobin absorbs more infrared light and less red light, while deoxygenated hemoglobin absorbs more red light and less infrared light.',
          category: 'PulseOx',
          difficulty: 'Easy',
        ),
      ],
      timeLimit: 420,
    ),
    Quiz(
      id: 'pulseox_clinical_quiz',
      title: 'Clinical Applications of Pulse Oximetry',
      description: 'Test your knowledge of pulse oximetry in clinical practice and disease states.',
      category: 'PulseOx',
      difficulty: 'Medium',
      questions: [
        QuizQuestion(
          id: 'pulseox_clinical_q1',
          question: 'Which of the following patient positions typically results in the highest SpO2 readings?',
          options: [
            'Supine position',
            'Prone position',
            'Sitting upright',
            'Left lateral decubitus position'
          ],
          correctAnswerIndex: 2,
          explanation: 'Sitting upright typically results in the highest SpO2 readings due to optimal lung expansion and ventilation-perfusion matching. The supine position often results in lower readings, especially in patients with obesity or respiratory conditions.',
          category: 'PulseOx',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'pulseox_clinical_q2',
          question: 'In a patient with COPD, what is typically the target SpO2 range for oxygen therapy?',
          options: [
            '95-100%',
            '90-94%',
            '88-92%',
            '80-85%'
          ],
          correctAnswerIndex: 2,
          explanation: 'In patients with COPD, the typical target SpO2 range for oxygen therapy is 88-92%. This lower range helps prevent oxygen-induced hypoventilation in patients who may have chronic hypercapnia and rely on hypoxic drive for ventilation.',
          category: 'PulseOx',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'pulseox_clinical_q3',
          question: 'During a 6-minute walk test, a patient\'s SpO2 drops from 95% at rest to 86% with exertion. This finding is most consistent with:',
          options: [
            'Normal physiological response to exercise',
            'Exercise-induced bronchospasm',
            'Exercise-induced hypoxemia due to lung disease',
            'Poor oximeter placement'
          ],
          correctAnswerIndex: 2,
          explanation: 'A drop in SpO2 from 95% at rest to 86% with exertion is abnormal and most consistent with exercise-induced hypoxemia due to underlying lung disease, such as interstitial lung disease, pulmonary vascular disease, or severe COPD. Normal exercise should not cause significant desaturation.',
          category: 'PulseOx',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'pulseox_clinical_q4',
          question: 'In the treatment of severe COVID-19 pneumonia, what SpO2 range is typically targeted with supplemental oxygen?',
          options: [
            '94-98%',
            '90-94%',
            '85-90%',
            '80-85%'
          ],
          correctAnswerIndex: 0,
          explanation: 'In severe COVID-19 pneumonia, the typically targeted SpO2 range with supplemental oxygen is 94-98%. Unlike COPD, there is no concern for hypoxic drive suppression, and maintaining adequate oxygenation is important to prevent end-organ damage.',
          category: 'PulseOx',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'pulseox_clinical_q5',
          question: 'A patient\'s pulse oximeter shows an SpO2 of 94% but arterial blood gas reveals a PaO2 of 60 mmHg. This discrepancy is most consistent with:',
          options: [
            'Normal variation',
            'Carbon monoxide poisoning',
            'Anemia',
            'Oximeter malfunction'
          ],
          correctAnswerIndex: 1,
          explanation: 'A normal SpO2 (94%) with a low PaO2 (60 mmHg) is most consistent with carbon monoxide poisoning. Carboxyhemoglobin has similar light absorption properties to oxyhemoglobin, causing the pulse oximeter to read falsely normal despite significant hypoxemia.',
          category: 'PulseOx',
          difficulty: 'Medium',
        ),
      ],
      timeLimit: 300,
    ),
    Quiz(
      id: 'cardiac_auscultation_quiz',
      title: 'Cardiac Auscultation Techniques',
      description: 'Test your knowledge of proper cardiac auscultation techniques and heart sound identification.',
      category: 'Cardiac Examination',
      difficulty: 'Medium',
      questions: [
        QuizQuestion(
          id: 'auscultation_q1',
          question: 'Which of the following locations is best for auscultating mitral valve sounds?',
          options: [
            'Right 2nd intercostal space',
            'Left 2nd intercostal space',
            'Lower left sternal border',
            'Apex (5th intercostal space, midclavicular line)'
          ],
          correctAnswerIndex: 3,
          explanation: 'The apex (5th intercostal space, midclavicular line) is the best location for auscultating mitral valve sounds, including mitral stenosis and mitral regurgitation murmurs.',
          category: 'Cardiac Examination',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'auscultation_q2',
          question: 'Which part of the stethoscope should be used to best hear high-pitched heart sounds like aortic regurgitation?',
          options: [
            'Bell',
            'Diaphragm',
            'Both work equally well',
            'Neither; an electronic stethoscope is required'
          ],
          correctAnswerIndex: 1,
          explanation: 'The diaphragm of the stethoscope should be used to best hear high-pitched heart sounds like aortic regurgitation murmurs, ejection clicks, and friction rubs. The bell is better for low-pitched sounds like S3, S4, and mitral stenosis murmurs.',
          category: 'Cardiac Examination',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'auscultation_q3',
          question: 'Which patient position best enhances the murmur of mitral stenosis?',
          options: [
            'Standing',
            'Supine',
            'Left lateral decubitus (left side down)',
            'Right lateral decubitus (right side down)'
          ],
          correctAnswerIndex: 2,
          explanation: 'The left lateral decubitus position (left side down) best enhances the murmur of mitral stenosis. This position brings the heart closer to the chest wall and increases left ventricular filling, making the mid-diastolic rumble more audible.',
          category: 'Cardiac Examination',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'auscultation_q4',
          question: 'Which maneuver would increase the intensity of mitral regurgitation murmur?',
          options: [
            'Valsalva maneuver',
            'Passive leg elevation',
            'Standing',
            'Handgrip'
          ],
          correctAnswerIndex: 3,
          explanation: 'Handgrip increases afterload (systemic vascular resistance), which typically increases the intensity of mitral regurgitation murmurs. The Valsalva maneuver and standing would decrease venous return and typically decrease the intensity of most murmurs except HOCM.',
          category: 'Cardiac Examination',
          difficulty: 'Medium',
        ),
        QuizQuestion(
          id: 'auscultation_q5',
          question: 'What is the correct sequence for systematic cardiac auscultation?',
          options: [
            'Apex, tricuspid area, pulmonic area, aortic area',
            'Aortic area, pulmonic area, tricuspid area, apex',
            'Anywhere, as long as all areas are covered',
            'Start at the apex and move clockwise around the precordium'
          ],
          correctAnswerIndex: 1,
          explanation: 'The correct sequence for systematic cardiac auscultation is aortic area (right 2nd intercostal space), pulmonic area (left 2nd intercostal space), tricuspid area (left lower sternal border), and apex (5th intercostal space, midclavicular line). This sequence follows the normal path of blood flow through the heart.',
          category: 'Cardiac Examination',
          difficulty: 'Medium',
        ),
      ],
      timeLimit: 300,
    ),
    Quiz(
      id: 'comprehensive_cardiology_quiz',
      title: 'Comprehensive Cardiology Assessment',
      description: 'A challenging quiz covering multiple aspects of cardiovascular assessment, including ECG, heart sounds, and clinical decision-making.',
      category: 'Comprehensive',
      difficulty: 'Hard',
      questions: [
        QuizQuestion(
          id: 'comprehensive_q1',
          question: 'A 65-year-old presents with dyspnea on exertion, a harsh mid-systolic murmur at the right upper sternal border radiating to the carotids, and a slow rising carotid pulse. The ECG shows left ventricular hypertrophy. What is the most likely diagnosis?',
          options: [
            'Mitral regurgitation',
            'Aortic stenosis',
            'Hypertrophic cardiomyopathy',
            'Aortic regurgitation'
          ],
          correctAnswerIndex: 1,
          explanation: 'This clinical picture is classic for aortic stenosis: a harsh mid-systolic murmur at the right upper sternal border radiating to the carotids, slow rising carotid pulse (pulsus parvus et tardus), dyspnea on exertion, and left ventricular hypertrophy on ECG.',
          category: 'Comprehensive',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'comprehensive_q2',
          question: 'A 30-year-old woman has an ECG showing sinus rhythm with first-degree AV block and incomplete right bundle branch block. She has no symptoms and a normal physical exam except for a widely split S2. What is the most likely diagnosis?',
          options: [
            'Ventricular septal defect',
            'Atrial septal defect',
            'Mitral valve prolapse',
            'Normal variant'
          ],
          correctAnswerIndex: 1,
          explanation: 'This clinical picture is consistent with an atrial septal defect (ASD). Key findings include a fixed widely split S2, first-degree AV block, and incomplete right bundle branch block on ECG, which are common in ASD due to right heart volume overload.',
          category: 'Comprehensive',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'comprehensive_q3',
          question: 'A patient has a loud S1, an opening snap, and a mid-diastolic rumble at the apex. Their SpO2 is 92% on room air, and their ECG shows atrial fibrillation with right axis deviation. What valve lesion is most likely?',
          options: [
            'Mitral stenosis',
            'Tricuspid stenosis',
            'Aortic regurgitation',
            'Mitral regurgitation'
          ],
          correctAnswerIndex: 0,
          explanation: 'These findings are classic for mitral stenosis: loud S1, opening snap, mid-diastolic rumble at the apex, atrial fibrillation (common complication due to left atrial enlargement), and right axis deviation on ECG (due to right ventricular overload from pulmonary hypertension).',
          category: 'Comprehensive',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'comprehensive_q4',
          question: 'A patient has an early diastolic murmur at the left sternal border, a wide pulse pressure, and head bobbing with each heartbeat. Their ECG shows left ventricular hypertrophy with volume overload pattern. What is the most likely diagnosis?',
          options: [
            'Aortic stenosis',
            'Mitral regurgitation',
            'Aortic regurgitation',
            'Patent ductus arteriosus'
          ],
          correctAnswerIndex: 2,
          explanation: 'This clinical picture describes aortic regurgitation: an early diastolic murmur at the left sternal border, wide pulse pressure, head bobbing (de Musset\'s sign), and LVH with volume overload on ECG. These findings result from regurgitation of blood from the aorta back into the left ventricle during diastole.',
          category: 'Comprehensive',
          difficulty: 'Hard',
        ),
        QuizQuestion(
          id: 'comprehensive_q5',
          question: 'A 16-year-old athlete has a systolic murmur that decreases when standing and increases when squatting. Their ECG is normal. What is the most likely diagnosis?',
          options: [
            'Hypertrophic cardiomyopathy',
            'Aortic stenosis',
            'Innocent flow murmur',
            'Mitral valve prolapse'
          ],
          correctAnswerIndex: 2,
          explanation: 'This is most likely an innocent flow murmur in a young athlete. Key points: the murmur decreases with standing and increases with squatting (opposite of HOCM), normal ECG (would likely show abnormalities in HOCM), and no concerning features. Innocent murmurs are common in young athletes due to increased stroke volume.',
          category: 'Comprehensive',
          difficulty: 'Hard',
        ),
      ],
      timeLimit: 300,
    ),
  ];
}

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
    ).join(' ');
  }
}
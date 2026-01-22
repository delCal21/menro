const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const {google} = require('googleapis');

admin.initializeApp();

const db = admin.firestore();
const COLLECTIONS_TO_BACKUP = ['reports', 'barangays', 'ordinances', 'users'];

async function logTransaction(entry) {
  await db.collection('transaction_logs').add({
    ...entry,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ========================================
// EMAIL CONFIGURATION
// ========================================
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'richardandrewo.prias@gmail.com', // UPDATE THIS
    pass: 'rgssisqwzrhgjwtl', // UPDATE THIS
  },
});

async function performBackup(triggerSource = 'manual') {
  const projectId = process.env.GCLOUD_PROJECT;
  const bucketName = process.env.BACKUP_BUCKET || `${projectId}.appspot.com`;
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputUriPrefix = `gs://${bucketName}/firestore_backups/${timestamp}`;

  const auth = await google.auth.getClient({
    scopes: ['https://www.googleapis.com/auth/datastore'],
  });
  const firestoreAdmin = google.firestore({
    version: 'v1',
    auth,
  });

  await firestoreAdmin.projects.databases.exportDocuments({
    name: `projects/${projectId}/databases/(default)`,
    requestBody: {
      outputUriPrefix,
      collectionIds: COLLECTIONS_TO_BACKUP,
    },
  });

  await logTransaction({
    type: 'backup',
    message: `Backup created via ${triggerSource}`,
    meta: outputUriPrefix,
  });

  return {filePath: outputUriPrefix};
}

// ========================================
// ROLE MANAGEMENT FUNCTIONS
// ========================================

// Function to set Admin role
exports.setAdminRole = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'Admin') {
    throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can assign admin role',
    );
  }

  const email = data.email;
  if (!email) {
    throw new functions.https.HttpsError(
        'invalid-argument',
        'Email is required',
    );
  }

  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().setCustomUserClaims(user.uid, {role: 'Admin'});
    return {message: `Success! ${email} is now an Admin.`};
  } catch (error) {
    throw new functions.https.HttpsError('unknown', error.message, error);
  }
});

// Function to set Barangay Official role
exports.setBarangayOfficialRole = functions.https
    .onCall(async (data, context) => {
      if (!context.auth || context.auth.token.role !== 'Admin') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins can assign barangay official role',
        );
      }

      const email = data.email;
      if (!email) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Email is required',
        );
      }

      try {
        const user = await admin.auth().getUserByEmail(email);
        const claims = {role: 'barangay_official'};
        await admin.auth().setCustomUserClaims(user.uid, claims);
        const msg = `Success! ${email} is now a Barangay Official.`;
        return {message: msg};
      } catch (error) {
        throw new functions.https.HttpsError('unknown', error.message, error);
      }
    });

exports.startBackup = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'Admin') {
    throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can trigger backups',
    );
  }

  try {
    const result = await performBackup('manual');
    return {message: 'Backup created', ...result};
  } catch (error) {
    console.error('Manual backup failed:', error);
    throw new functions.https.HttpsError(
        'internal',
        error.message || 'Backup failed',
        error,
    );
  }
});

exports.weeklyBackup = functions.pubsub
    .schedule('every monday 01:00')
    .timeZone('Asia/Manila')
    .onRun(async () => {
      try {
        const result = await performBackup('scheduled');
        console.log('Scheduled backup stored at', result.filePath);
      } catch (error) {
        console.error('Scheduled backup failed:', error);
      }
      return null;
    });

// ========================================
// EMAIL NOTIFICATION FUNCTION
// ========================================

// Send email when user is approved
exports.sendApprovalEmail = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const statusChanged = beforeData.status === 'pending' &&
          afterData.status === 'approved';

      if (statusChanged) {
        const userEmail = afterData.email;
        const userName = afterData.name;

        const mailOptions = {
          from: 'Your App <richardandrewo.prias@gmail.com>', // UPDATE THIS
          to: userEmail,
          subject: 'Your Account Has Been Approved!',
          html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
              }
              .container {
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
              }
              .header {
                background-color: #0A4D68;
                color: white;
                padding: 30px;
                text-align: center;
                border-radius: 8px 8px 0 0;
              }
              .content {
                background-color: #f9f9f9;
                padding: 30px;
                border-radius: 0 0 8px 8px;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>Account Approved!</h1>
              </div>
              <div class="content">
                <p>Hi <strong>${userName}</strong>,</p>
                <p>Your account has been approved by our admin team.</p>
                <p>You can now log in and start using our services.</p>
                <p>Best regards,<br><strong>The Team</strong></p>
              </div>
            </div>
          </body>
          </html>
        `,
        };

        try {
          await transporter.sendMail(mailOptions);
          console.log(`Approval email sent to ${userEmail}`);
          return null;
        } catch (error) {
          console.error('Error sending email:', error);
          return null;
        }
      }

      return null;
    });

exports.logReportCreated = functions.firestore
    .document('reports/{reportId}')
    .onCreate(async (snap, context) => {
      const data = snap.data();
      await logTransaction({
        type: 'report_created',
        message: `Report submitted for ${data.address ?? 'unknown address'}`,
        meta: {
          ordinance: data.ordinance,
          status: data.status,
        },
        reportId: context.params.reportId,
      });
      return null;
    });

exports.logReportUpdated = functions.firestore
    .document('reports/{reportId}')
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      const changed = [];
      if (before.status !== after.status) {
        changed.push(`status: ${before.status} → ${after.status}`);
      }
      if ((before.actionTaken || '') !== (after.actionTaken || '')) {
        changed.push('action updated');
      }

      if (changed.length === 0) {
        return null;
      }

      await logTransaction({
        type: 'report_updated',
        message: `Report ${context.params.reportId} updated (${changed.join(', ')})`,
        meta: {status: after.status},
        reportId: context.params.reportId,
      });
      return null;
    });
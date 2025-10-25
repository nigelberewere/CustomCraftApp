import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

// Initialize the Firebase Admin SDK
initializeApp();
const db = getFirestore();


export const onProjectDeleted = onDocumentDeleted("projects/{projectId}",
  async (event) => {
    // Get the ID of the project that was just deleted
    const projectId = event.params.projectId;
    const logPrefix = `Project ${projectId}:`;
    console.log(`${logPrefix} Cleaning up subcollections`);

    try {
      // Get the project document reference
      const projectRef = db.collection("projects").doc(projectId);

      // List all collections under this project
      const collections = await projectRef.listCollections();

      // Process each subcollection
      for (const collectionRef of collections) {
        const collectionId = collectionRef.id;
        console.log(`${logPrefix} Processing ${collectionId}`);

        // Get all documents from the subcollection
        const querySnapshot = await collectionRef.get();

        // If there are no documents, continue to next collection
        if (querySnapshot.empty) {
          console.log(`${logPrefix} No documents in ${collectionId}`);
          continue;
        }

        // Create a batch for this collection's deletions
        const batch = db.batch();
        let count = 0;

        // Add each document to the deletion batch
        for (const doc of querySnapshot.docs) {
          batch.delete(doc.ref);
          count++;
        }

        // Commit the batch
        await batch.commit();
        console.log(`${logPrefix} Deleted ${count} docs from ${collectionId}`);
      }

      console.log(`${logPrefix} Successfully cleaned up all subcollections`);
    } catch (error) {
      console.error(`${logPrefix} Cleanup failed:`, error);
      throw new HttpsError("internal", "Failed to clean up project data");
    }
  }
);

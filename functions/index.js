/**
 * AgroLens Cloud Functions.
 *
 * pushNotification   – whenever something lands in a user's notification
 *                      list (notifications/{uid}/items), send it to their
 *                      phones, unless they switched that kind off in Settings.
 * cleanUpDeletedUser – when an account is deleted, remove everything the
 *                      user created (profile, posts, comments, diagnoses,
 *                      pals, conversations, notifications).
 *
 * Disease outbreak alerts are not here: the news scraper sends those to
 * the `disease_alerts` topic directly.
 *
 * Deploy: firebase deploy --only functions   (needs the Blaze plan)
 */

const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const functionsV1 = require("firebase-functions/v1");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

const {categoryFor, pushText, shouldPush} = require("./messages");

initializeApp();
const db = getFirestore();

const DEAD_TOKEN_ERRORS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

exports.pushNotification = onDocumentWritten(
  "notifications/{uid}/items/{itemId}",
  async (event) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!shouldPush(before, after)) return;

    const {uid, itemId} = event.params;
    const category = categoryFor(after.type);

    const privateRef = db.doc(`users/${uid}/private/notifications`);
    const snap = await privateRef.get();
    const prefs = snap.get("prefs") || {};
    if (prefs[category] === false) return;

    const tokens = snap.get("tokens") || [];
    if (tokens.length === 0) return;

    const {title, body} = pushText(after);
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {
        type: String(after.type || ""),
        itemId,
        conversationId: String(after.conversationId || ""),
        postId: String(after.postId || ""),
      },
      android: {
        // One notification per chat/post on the phone, replaced on update.
        notification: {channelId: category, tag: itemId},
      },
      apns: {payload: {aps: {threadId: itemId}}},
    });

    const dead = tokens.filter((_, i) => {
      const r = result.responses[i];
      return !r.success && DEAD_TOKEN_ERRORS.has(r.error?.code);
    });
    if (dead.length) {
      await privateRef.update({tokens: FieldValue.arrayRemove(...dead)});
    }
    logger.info(`push ${after.type} to ${uid}: ${result.successCount} sent, ${dead.length} dead tokens removed`);
  },
);

exports.cleanUpDeletedUser = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const deleteAll = async (query) => {
    const snap = await query.get();
    await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
    return snap.size;
  };

  const counts = {
    posts: await deleteAll(db.collection("posts").where("uid", "==", uid)),
    comments: await deleteAll(db.collectionGroup("comments").where("uid", "==", uid)),
    diagnoses: await deleteAll(db.collection("diagnoses").where("uid", "==", uid)),
    palRequestsSent: await deleteAll(db.collection("palRequests").where("fromUid", "==", uid)),
    palRequestsReceived: await deleteAll(db.collection("palRequests").where("toUid", "==", uid)),
    pals: await deleteAll(db.collection("pals").where("uid", "==", uid)),
    palsOf: await deleteAll(db.collection("pals").where("otherUid", "==", uid)),
    conversations: await deleteAll(
      db.collection("conversations").where("participants", "array-contains", uid),
    ),
  };
  await db.recursiveDelete(db.doc(`notifications/${uid}`));
  await db.recursiveDelete(db.doc(`users/${uid}`));

  logger.info(`Deleted data for ${uid}`, counts);
});

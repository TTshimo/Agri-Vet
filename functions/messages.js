// Pure helpers for push notifications (no Firebase imports, so they can be
// unit-tested with `npm test`).

/** Which Settings switch (and Android channel) each notification type uses. */
const CATEGORY = {
  like: "community",
  comment: "community",
  reply: "community",
  pal_request: "community",
  pal_accept: "community",
  msg_request: "messages",
  msg_accept: "messages",
  message: "messages",
};

function categoryFor(type) {
  return CATEGORY[type] || "community";
}

/** Title and body of the push, matching the wording of the in-app list. */
function pushText(data) {
  const name = data.fromName || "A farmer";
  switch (data.type) {
    case "like":
      return {title: "New like", body: `${name} liked your post`};
    case "comment":
      return {title: "New comment", body: `${name} commented on your post`};
    case "reply":
      return {title: "New reply", body: `${name} replied to your comment`};
    case "pal_request":
      return {title: "Pal request", body: `${name} sent you a pal request`};
    case "pal_accept":
      return {title: "New pal", body: `${name} accepted your pal request`};
    case "msg_request":
      return {title: "Message request", body: `${name} wants to message you`};
    case "msg_accept":
      return {title: "Request accepted", body: `${name} accepted your message request`};
    case "message":
      return {title: name, body: data.preview || "Sent you a message"};
    default:
      return {title: "AgroLens", body: "You have a new notification"};
  }
}

/**
 * Should this write to notifications/{uid}/items/{id} produce a push?
 * Yes for a new unread notification, and for a chat notification that the
 * sender overwrote with a newer message. No when the owner only marked it
 * read, or it was deleted.
 */
function shouldPush(before, after) {
  if (!after || after.read === true) return false;
  if (!before) return true;
  const a = after.updatedAt;
  const b = before.updatedAt;
  if (!a) return false;
  if (!b) return true;
  return typeof a.isEqual === "function" ? !a.isEqual(b) : String(a) !== String(b);
}

module.exports = {categoryFor, pushText, shouldPush};

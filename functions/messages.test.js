const test = require("node:test");
const assert = require("node:assert");
const {categoryFor, pushText, shouldPush} = require("./messages");

const ts = (n) => ({isEqual: (o) => o.n === n, n});

test("categories match the Settings switches", () => {
  assert.equal(categoryFor("like"), "community");
  assert.equal(categoryFor("pal_request"), "community");
  assert.equal(categoryFor("message"), "messages");
  assert.equal(categoryFor("msg_request"), "messages");
  assert.equal(categoryFor("something_new"), "community");
});

test("push text", () => {
  assert.deepEqual(pushText({type: "like", fromName: "Neo"}), {title: "New like", body: "Neo liked your post"});
  assert.deepEqual(pushText({type: "message", fromName: "Neo", preview: "Dumela!"}), {title: "Neo", body: "Dumela!"});
});

test("when to push", () => {
  assert.equal(shouldPush(null, {read: false}), true, "new notification");
  assert.equal(shouldPush(null, {read: true}), false);
  assert.equal(shouldPush({read: false}, null), false, "deleted");
  assert.equal(shouldPush({read: false, updatedAt: ts(1)}, {read: true, updatedAt: ts(1)}), false, "marked read");
  assert.equal(shouldPush({read: true, updatedAt: ts(1)}, {read: false, updatedAt: ts(2)}), true, "new chat message");
  assert.equal(shouldPush({read: false}, {read: false}), false, "other edit, not a new message");
});

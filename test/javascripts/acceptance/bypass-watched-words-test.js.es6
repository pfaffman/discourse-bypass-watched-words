import { acceptance } from "helpers/qunit-helpers";

acceptance("BypassWatchedWords", { loggedIn: true });

test("BypassWatchedWords works", async assert => {
  await visit("/admin/plugins/bypass-watched-words");

  assert.ok(false, "it shows the BypassWatchedWords button");
});

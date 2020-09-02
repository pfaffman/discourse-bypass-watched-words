export default function() {
  this.route("bypass-watched-words", function() {
    this.route("actions", function() {
      this.route("show", { path: "/:id" });
    });
  });
};

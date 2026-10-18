const express = require("express");

const app = express();
const port = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send("Application is running.");
});

// Contract used by the deploy workflow: 200 with {status:"ok", sha:<deployed commit>}.
app.get("/health", (req, res) => {
  res.json({ status: "ok", sha: process.env.GIT_SHA || "unknown" });
});

app.listen(port, () => {
  console.log(`Listening on port ${port}`);
});

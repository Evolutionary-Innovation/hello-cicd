const express = require("express");

const app = express();

app.get("/", (req, res) => {
//   res.send("Hello from CI/CD Pipeline!");
  res.send("Terraform CI/CD Pipeline - Version 5: Docker Image");
});

app.listen(3000, () => {
  console.log("Listening on port 3000");
});

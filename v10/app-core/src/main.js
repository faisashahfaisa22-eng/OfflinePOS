// POS & Accounts Pro v10 - Core Application Starter

const App = {
  version: "10.27.0-alpha",

  init() {
    console.log("POS & Accounts Pro started");
    Database.init();
  }
};

const Database = {
  init() {
    console.log("Local database initialized");
  }
};

App.init();

const { defineConfig } = require("cypress");

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    baseUrl: 'http://localhost:8080/exist/apps/public-repo/',
    fixturesFolder: "test/cypress/fixtures",
    screenshotsFolder: "test/cypress/screenshots",
    videosFolder: "test/cypress/videos",
    downloadsFolder: "test/cypress/downloads",
    supportFile: "test/cypress/support/e2e.js",
    specPattern: 'test/cypress/e2e/**/*.{js,jsx,ts,tsx}',
  },
});

import { defineConfig, devices } from "@playwright/test";

const isProduction = !process.env.NODE_ENV || process.env.NODE_ENV === "production";
const port = process.env.PORT || "3000";
const baseURL = `http://localhost:${port}`;

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "list",
  use: {
    baseURL,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: isProduction ? "bun run serve" : "bun run dev",
    url: baseURL,
    reuseExistingServer: !process.env.CI,
  },
});

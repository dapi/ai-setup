import { expect, test } from "@playwright/test";

test("home page displays greeting", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Hello, World!" })).toBeVisible();
});

import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import type { server as serverExport } from "../../index";

type ServerInstance = typeof serverExport;

let server: ServerInstance;

beforeAll(async () => {
  ({ server } = await import("../../index"));
});

afterAll(async () => {
  await server.stop();
});

describe("GET /api/appeal", () => {
  test("returns status 200", async () => {
    const res = await fetch(`${server.url}api/appeal`);
    expect(res.status).toBe(200);
  });

  test("returns Content-Type application/json", async () => {
    const res = await fetch(`${server.url}api/appeal`);
    expect(res.headers.get("content-type")).toContain("application/json");
  });

  test("returns body with appeal field", async () => {
    const res = await fetch(`${server.url}api/appeal`);
    const body = await res.json();
    expect(body).toEqual({ appeal: "World" });
  });
});

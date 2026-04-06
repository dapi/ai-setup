import { apiRoutes } from "./app/api-routes";
import index from "./index.html";
import { serve } from "bun";

export const server = serve({
  development: process.env.NODE_ENV === "development" && {
    console: true,
    hmr: true,
  },

  routes: {
    "/*": index,
    ...apiRoutes,
  },
});

console.log(`Server running at ${server.url}`);

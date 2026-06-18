/// <reference types="@cloudflare/workers-types" />

// Cloudflare runtime bindings exposed to Astro endpoints.
// In Astro 6, `Astro.locals.runtime.env` was removed; endpoints now read
// bindings via `import { env } from "cloudflare:workers"`.
declare namespace Cloudflare {
  interface Env {
    ASSETS: Fetcher;
    IMAGES?: unknown;
    SESSION?: unknown;
  }
}

type Env = Cloudflare.Env;

declare namespace App {
  interface Locals {
    cfContext: ExecutionContext;
    runtime: {
      cf?: IncomingRequestCfProperties;
    };
  }
}

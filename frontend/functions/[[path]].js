const API_PATHS = ["/api", "/auth", "/graphql", "/up", "/ready"];

function isApiRequest(pathname) {
  return API_PATHS.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store"
    }
  });
}

export async function onRequest(context) {
  const requestUrl = new URL(context.request.url);
  if (!isApiRequest(requestUrl.pathname)) return context.next();

  const apiOrigin = context.env.API_ORIGIN?.trim();
  if (!apiOrigin) return jsonError("API proxy is not configured", 503);

  let upstreamUrl;
  try {
    upstreamUrl = new URL(`${requestUrl.pathname}${requestUrl.search}`, apiOrigin);
  } catch {
    return jsonError("API proxy origin is invalid", 503);
  }

  const headers = new Headers(context.request.headers);
  headers.delete("Host");
  headers.delete("Origin");
  headers.delete("Referer");
  headers.set("X-Forwarded-Host", requestUrl.host);
  headers.set("X-Forwarded-Proto", "https");

  try {
    const upstreamRequest = new Request(upstreamUrl, {
      method: context.request.method,
      headers,
      body: ["GET", "HEAD"].includes(context.request.method) ? undefined : context.request.body,
      redirect: "manual"
    });
    const upstreamResponse = await fetch(upstreamRequest);
    const responseHeaders = new Headers(upstreamResponse.headers);
    responseHeaders.set("Cache-Control", "no-store");
    responseHeaders.delete("Access-Control-Allow-Origin");
    responseHeaders.delete("Access-Control-Allow-Credentials");

    return new Response(upstreamResponse.body, {
      status: upstreamResponse.status,
      statusText: upstreamResponse.statusText,
      headers: responseHeaders
    });
  } catch (error) {
    console.error("API proxy request failed", {
      method: context.request.method,
      path: requestUrl.pathname,
      message: error instanceof Error ? error.message : "Unknown proxy error"
    });
    return jsonError("The API is temporarily unavailable. Please try again shortly.", 502);
  }
}

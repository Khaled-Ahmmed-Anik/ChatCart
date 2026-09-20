import { GraphQLClient, type Variables } from "graphql-request";
import type { TypedDocumentNode } from "@graphql-typed-document-node/core";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:3000";

export async function graphqlRequest<TResult, TVariables extends Variables>(
  document: TypedDocumentNode<TResult, TVariables>,
  variables?: TVariables
): Promise<TResult> {
  const token = localStorage.getItem("chatcart_session_token");
  const client = new GraphQLClient(`${API_URL}/graphql`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {}
  });

  try {
    return await client.request(document, variables);
  } catch (error) {
    const status = typeof error === "object" && error && "response" in error
      ? (error.response as { status?: number }).status
      : undefined;
    if (status === 401) {
      localStorage.removeItem("chatcart_session_token");
      localStorage.removeItem("chatcart_auth");
      window.dispatchEvent(new Event("chatcart:unauthorized"));
    }
    throw error;
  }
}

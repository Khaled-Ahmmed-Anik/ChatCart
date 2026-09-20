/* eslint-disable */
/** Internal type. DO NOT USE DIRECTLY. */
type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
/** Internal type. DO NOT USE DIRECTLY. */
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';
export type ProductInput = {
  active?: boolean | null | undefined;
  benefits?: string | null | undefined;
  category?: string | null | undefined;
  description?: string | null | undefined;
  name: string;
  price: string;
  productAttributes?: unknown;
  shortDescription?: string | null | undefined;
  stockQuantity: number;
  suitableFor?: string | null | undefined;
  tags?: string | null | undefined;
  usageInstructions?: string | null | undefined;
  variants?: Array<ProductVariantInput> | null | undefined;
  wooCommerceProductId?: string | null | undefined;
};

export type ProductVariantInput = {
  active?: boolean | null | undefined;
  id?: string | number | null | undefined;
  name: string;
  position?: number | null | undefined;
  price: string;
  size?: string | null | undefined;
  sku?: string | null | undefined;
  stockQuantity: number;
};

export type DashboardContextQueryVariables = Exact<{ [key: string]: never; }>;


export type DashboardContextQuery = { viewer: { id: string, name: string, email: string, role: string }, currentBusiness: { id: string, name: string, slug: string, category: string | null, defaultLanguage: string, timezone: string, currency: string, status: string } };

export type DashboardAnalyticsQueryVariables = Exact<{ [key: string]: never; }>;


export type DashboardAnalyticsQuery = { analytics: { conversations: number, uniqueCustomers: number, confirmedOrders: number, conversationToOrderRate: number, orderingCustomers: number, repeatCustomers: number, repeatCustomerRate: number, revenue: string, averageOrderValue: string, ordersByChannel: unknown, ordersByStatus: unknown, topProducts: unknown } };

export type DashboardProductsQueryVariables = Exact<{
  first?: number | null | undefined;
}>;


export type DashboardProductsQuery = { products: Array<{ id: string, name: string, description: string | null, shortDescription: string | null, category: string | null, benefits: string | null, usageInstructions: string | null, suitableFor: string | null, productAttributes: unknown, price: string, stockQuantity: number, tags: string | null, active: boolean, wooCommerceProductId: string | null, variants: Array<{ id: string, name: string, size: string | null, sku: string | null, price: string, stockQuantity: number, active: boolean, position: number }> }> };

export type SaveDashboardProductMutationVariables = Exact<{
  id?: string | number | null | undefined;
  input: ProductInput;
}>;


export type SaveDashboardProductMutation = { saveProduct: { errors: Array<string>, product: { id: string, name: string, description: string | null, shortDescription: string | null, category: string | null, benefits: string | null, usageInstructions: string | null, suitableFor: string | null, productAttributes: unknown, price: string, stockQuantity: number, tags: string | null, active: boolean, wooCommerceProductId: string | null, variants: Array<{ id: string, name: string, size: string | null, sku: string | null, price: string, stockQuantity: number, active: boolean, position: number }> } | null } | null };


export const DashboardContextDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DashboardContext"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"viewer"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"email"}},{"kind":"Field","name":{"kind":"Name","value":"role"}}]}},{"kind":"Field","name":{"kind":"Name","value":"currentBusiness"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"slug"}},{"kind":"Field","name":{"kind":"Name","value":"category"}},{"kind":"Field","name":{"kind":"Name","value":"defaultLanguage"}},{"kind":"Field","name":{"kind":"Name","value":"timezone"}},{"kind":"Field","name":{"kind":"Name","value":"currency"}},{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<DashboardContextQuery, DashboardContextQueryVariables>;
export const DashboardAnalyticsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DashboardAnalytics"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"analytics"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"conversations"}},{"kind":"Field","name":{"kind":"Name","value":"uniqueCustomers"}},{"kind":"Field","name":{"kind":"Name","value":"confirmedOrders"}},{"kind":"Field","name":{"kind":"Name","value":"conversationToOrderRate"}},{"kind":"Field","name":{"kind":"Name","value":"orderingCustomers"}},{"kind":"Field","name":{"kind":"Name","value":"repeatCustomers"}},{"kind":"Field","name":{"kind":"Name","value":"repeatCustomerRate"}},{"kind":"Field","name":{"kind":"Name","value":"revenue"}},{"kind":"Field","name":{"kind":"Name","value":"averageOrderValue"}},{"kind":"Field","name":{"kind":"Name","value":"ordersByChannel"}},{"kind":"Field","name":{"kind":"Name","value":"ordersByStatus"}},{"kind":"Field","name":{"kind":"Name","value":"topProducts"}}]}}]}}]} as unknown as DocumentNode<DashboardAnalyticsQuery, DashboardAnalyticsQueryVariables>;
export const DashboardProductsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DashboardProducts"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"first"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}},"defaultValue":{"kind":"IntValue","value":"50"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"products"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"first"},"value":{"kind":"Variable","name":{"kind":"Name","value":"first"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"shortDescription"}},{"kind":"Field","name":{"kind":"Name","value":"category"}},{"kind":"Field","name":{"kind":"Name","value":"benefits"}},{"kind":"Field","name":{"kind":"Name","value":"usageInstructions"}},{"kind":"Field","name":{"kind":"Name","value":"suitableFor"}},{"kind":"Field","name":{"kind":"Name","value":"productAttributes"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"tags"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"wooCommerceProductId"}},{"kind":"Field","name":{"kind":"Name","value":"variants"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"size"}},{"kind":"Field","name":{"kind":"Name","value":"sku"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"position"}}]}}]}}]}}]} as unknown as DocumentNode<DashboardProductsQuery, DashboardProductsQueryVariables>;
export const SaveDashboardProductDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"SaveDashboardProduct"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"input"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ProductInput"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"saveProduct"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"input"},"value":{"kind":"Variable","name":{"kind":"Name","value":"input"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"product"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"shortDescription"}},{"kind":"Field","name":{"kind":"Name","value":"category"}},{"kind":"Field","name":{"kind":"Name","value":"benefits"}},{"kind":"Field","name":{"kind":"Name","value":"usageInstructions"}},{"kind":"Field","name":{"kind":"Name","value":"suitableFor"}},{"kind":"Field","name":{"kind":"Name","value":"productAttributes"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"tags"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"wooCommerceProductId"}},{"kind":"Field","name":{"kind":"Name","value":"variants"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"size"}},{"kind":"Field","name":{"kind":"Name","value":"sku"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"position"}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"errors"}}]}}]}}]} as unknown as DocumentNode<SaveDashboardProductMutation, SaveDashboardProductMutationVariables>;
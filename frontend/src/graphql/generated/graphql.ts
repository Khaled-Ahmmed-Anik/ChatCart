/* eslint-disable */
/** Internal type. DO NOT USE DIRECTLY. */
type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
/** Internal type. DO NOT USE DIRECTLY. */
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';
export type ComboItemInput = {
  componentProductId: string | number;
  id?: string | number | null | undefined;
  position?: number | null | undefined;
  quantity?: number | null | undefined;
  required?: boolean | null | undefined;
  selectionGroup?: string | null | undefined;
};

export type ProductInput = {
  active?: boolean | null | undefined;
  aliases?: Array<string> | null | undefined;
  benefits?: string | null | undefined;
  category?: string | null | undefined;
  comboItems?: Array<ComboItemInput> | null | undefined;
  description?: string | null | undefined;
  imageUrls?: Array<string> | null | undefined;
  name: string;
  price: string;
  productAttributes?: unknown;
  productType?: string | null | undefined;
  shortDescription?: string | null | undefined;
  sourceUrl?: string | null | undefined;
  stockQuantity: number;
  stockStrategy?: string | null | undefined;
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


export type DashboardProductsQuery = { products: Array<{ id: string, name: string, description: string | null, shortDescription: string | null, category: string | null, benefits: string | null, usageInstructions: string | null, suitableFor: string | null, productAttributes: unknown, price: string, stockQuantity: number, tags: string | null, active: boolean, wooCommerceProductId: string | null, productType: string, stockStrategy: string, aliases: Array<string>, imageUrls: Array<string>, sourceUrl: string | null, archivedAt: unknown, variants: Array<{ id: string, name: string, size: string | null, sku: string | null, price: string, stockQuantity: number, active: boolean, position: number }>, comboItems: Array<{ id: string, quantity: number, selectionGroup: string | null, required: boolean, position: number, componentProduct: { id: string, name: string } }> }> };

export type SaveDashboardProductMutationVariables = Exact<{
  id?: string | number | null | undefined;
  input: ProductInput;
}>;


export type SaveDashboardProductMutation = { saveProduct: { errors: Array<string>, product: { id: string, name: string, description: string | null, shortDescription: string | null, category: string | null, benefits: string | null, usageInstructions: string | null, suitableFor: string | null, productAttributes: unknown, price: string, stockQuantity: number, tags: string | null, active: boolean, wooCommerceProductId: string | null, productType: string, stockStrategy: string, aliases: Array<string>, imageUrls: Array<string>, sourceUrl: string | null, archivedAt: unknown, variants: Array<{ id: string, name: string, size: string | null, sku: string | null, price: string, stockQuantity: number, active: boolean, position: number }>, comboItems: Array<{ id: string, quantity: number, selectionGroup: string | null, required: boolean, position: number, componentProduct: { id: string, name: string } }> } | null } | null };

export type ArchiveDashboardProductMutationVariables = Exact<{
  id: string | number;
  permanent?: boolean | null | undefined;
}>;


export type ArchiveDashboardProductMutation = { archiveProduct: { deleted: boolean, errors: Array<string>, product: { id: string, active: boolean, archivedAt: unknown } | null } | null };

export type PreviewDashboardProductImportMutationVariables = Exact<{
  url: string;
}>;


export type PreviewDashboardProductImportMutation = { previewProductImport: { errors: Array<string>, draft: { id: string, sourceUrl: string, status: string, extractedData: unknown, error: string | null } | null } | null };

export type ApproveDashboardProductImportMutationVariables = Exact<{
  draftId: string | number;
}>;


export type ApproveDashboardProductImportMutation = { approveProductImport: { errors: Array<string>, product: { id: string, name: string, active: boolean, sourceUrl: string | null } | null } | null };


export const DashboardContextDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DashboardContext"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"viewer"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"email"}},{"kind":"Field","name":{"kind":"Name","value":"role"}}]}},{"kind":"Field","name":{"kind":"Name","value":"currentBusiness"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"slug"}},{"kind":"Field","name":{"kind":"Name","value":"category"}},{"kind":"Field","name":{"kind":"Name","value":"defaultLanguage"}},{"kind":"Field","name":{"kind":"Name","value":"timezone"}},{"kind":"Field","name":{"kind":"Name","value":"currency"}},{"kind":"Field","name":{"kind":"Name","value":"status"}}]}}]}}]} as unknown as DocumentNode<DashboardContextQuery, DashboardContextQueryVariables>;
export const DashboardAnalyticsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DashboardAnalytics"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"analytics"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"conversations"}},{"kind":"Field","name":{"kind":"Name","value":"uniqueCustomers"}},{"kind":"Field","name":{"kind":"Name","value":"confirmedOrders"}},{"kind":"Field","name":{"kind":"Name","value":"conversationToOrderRate"}},{"kind":"Field","name":{"kind":"Name","value":"orderingCustomers"}},{"kind":"Field","name":{"kind":"Name","value":"repeatCustomers"}},{"kind":"Field","name":{"kind":"Name","value":"repeatCustomerRate"}},{"kind":"Field","name":{"kind":"Name","value":"revenue"}},{"kind":"Field","name":{"kind":"Name","value":"averageOrderValue"}},{"kind":"Field","name":{"kind":"Name","value":"ordersByChannel"}},{"kind":"Field","name":{"kind":"Name","value":"ordersByStatus"}},{"kind":"Field","name":{"kind":"Name","value":"topProducts"}}]}}]}}]} as unknown as DocumentNode<DashboardAnalyticsQuery, DashboardAnalyticsQueryVariables>;
export const DashboardProductsDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"query","name":{"kind":"Name","value":"DashboardProducts"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"first"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Int"}},"defaultValue":{"kind":"IntValue","value":"50"}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"products"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"first"},"value":{"kind":"Variable","name":{"kind":"Name","value":"first"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"shortDescription"}},{"kind":"Field","name":{"kind":"Name","value":"category"}},{"kind":"Field","name":{"kind":"Name","value":"benefits"}},{"kind":"Field","name":{"kind":"Name","value":"usageInstructions"}},{"kind":"Field","name":{"kind":"Name","value":"suitableFor"}},{"kind":"Field","name":{"kind":"Name","value":"productAttributes"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"tags"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"wooCommerceProductId"}},{"kind":"Field","name":{"kind":"Name","value":"productType"}},{"kind":"Field","name":{"kind":"Name","value":"stockStrategy"}},{"kind":"Field","name":{"kind":"Name","value":"aliases"}},{"kind":"Field","name":{"kind":"Name","value":"imageUrls"}},{"kind":"Field","name":{"kind":"Name","value":"sourceUrl"}},{"kind":"Field","name":{"kind":"Name","value":"archivedAt"}},{"kind":"Field","name":{"kind":"Name","value":"variants"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"size"}},{"kind":"Field","name":{"kind":"Name","value":"sku"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"position"}}]}},{"kind":"Field","name":{"kind":"Name","value":"comboItems"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"quantity"}},{"kind":"Field","name":{"kind":"Name","value":"selectionGroup"}},{"kind":"Field","name":{"kind":"Name","value":"required"}},{"kind":"Field","name":{"kind":"Name","value":"position"}},{"kind":"Field","name":{"kind":"Name","value":"componentProduct"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}}]}}]}}]}}]}}]} as unknown as DocumentNode<DashboardProductsQuery, DashboardProductsQueryVariables>;
export const SaveDashboardProductDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"SaveDashboardProduct"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"input"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ProductInput"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"saveProduct"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"input"},"value":{"kind":"Variable","name":{"kind":"Name","value":"input"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"product"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"description"}},{"kind":"Field","name":{"kind":"Name","value":"shortDescription"}},{"kind":"Field","name":{"kind":"Name","value":"category"}},{"kind":"Field","name":{"kind":"Name","value":"benefits"}},{"kind":"Field","name":{"kind":"Name","value":"usageInstructions"}},{"kind":"Field","name":{"kind":"Name","value":"suitableFor"}},{"kind":"Field","name":{"kind":"Name","value":"productAttributes"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"tags"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"wooCommerceProductId"}},{"kind":"Field","name":{"kind":"Name","value":"productType"}},{"kind":"Field","name":{"kind":"Name","value":"stockStrategy"}},{"kind":"Field","name":{"kind":"Name","value":"aliases"}},{"kind":"Field","name":{"kind":"Name","value":"imageUrls"}},{"kind":"Field","name":{"kind":"Name","value":"sourceUrl"}},{"kind":"Field","name":{"kind":"Name","value":"archivedAt"}},{"kind":"Field","name":{"kind":"Name","value":"variants"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"size"}},{"kind":"Field","name":{"kind":"Name","value":"sku"}},{"kind":"Field","name":{"kind":"Name","value":"price"}},{"kind":"Field","name":{"kind":"Name","value":"stockQuantity"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"position"}}]}},{"kind":"Field","name":{"kind":"Name","value":"comboItems"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"quantity"}},{"kind":"Field","name":{"kind":"Name","value":"selectionGroup"}},{"kind":"Field","name":{"kind":"Name","value":"required"}},{"kind":"Field","name":{"kind":"Name","value":"position"}},{"kind":"Field","name":{"kind":"Name","value":"componentProduct"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}}]}}]}}]}},{"kind":"Field","name":{"kind":"Name","value":"errors"}}]}}]}}]} as unknown as DocumentNode<SaveDashboardProductMutation, SaveDashboardProductMutationVariables>;
export const ArchiveDashboardProductDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"ArchiveDashboardProduct"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"id"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}},{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"permanent"}},"type":{"kind":"NamedType","name":{"kind":"Name","value":"Boolean"}},"defaultValue":{"kind":"BooleanValue","value":false}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"archiveProduct"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"id"},"value":{"kind":"Variable","name":{"kind":"Name","value":"id"}}},{"kind":"Argument","name":{"kind":"Name","value":"permanent"},"value":{"kind":"Variable","name":{"kind":"Name","value":"permanent"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"deleted"}},{"kind":"Field","name":{"kind":"Name","value":"product"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"archivedAt"}}]}},{"kind":"Field","name":{"kind":"Name","value":"errors"}}]}}]}}]} as unknown as DocumentNode<ArchiveDashboardProductMutation, ArchiveDashboardProductMutationVariables>;
export const PreviewDashboardProductImportDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"PreviewDashboardProductImport"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"url"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"String"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"previewProductImport"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"url"},"value":{"kind":"Variable","name":{"kind":"Name","value":"url"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"draft"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"sourceUrl"}},{"kind":"Field","name":{"kind":"Name","value":"status"}},{"kind":"Field","name":{"kind":"Name","value":"extractedData"}},{"kind":"Field","name":{"kind":"Name","value":"error"}}]}},{"kind":"Field","name":{"kind":"Name","value":"errors"}}]}}]}}]} as unknown as DocumentNode<PreviewDashboardProductImportMutation, PreviewDashboardProductImportMutationVariables>;
export const ApproveDashboardProductImportDocument = {"kind":"Document","definitions":[{"kind":"OperationDefinition","operation":"mutation","name":{"kind":"Name","value":"ApproveDashboardProductImport"},"variableDefinitions":[{"kind":"VariableDefinition","variable":{"kind":"Variable","name":{"kind":"Name","value":"draftId"}},"type":{"kind":"NonNullType","type":{"kind":"NamedType","name":{"kind":"Name","value":"ID"}}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"approveProductImport"},"arguments":[{"kind":"Argument","name":{"kind":"Name","value":"draftId"},"value":{"kind":"Variable","name":{"kind":"Name","value":"draftId"}}}],"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"product"},"selectionSet":{"kind":"SelectionSet","selections":[{"kind":"Field","name":{"kind":"Name","value":"id"}},{"kind":"Field","name":{"kind":"Name","value":"name"}},{"kind":"Field","name":{"kind":"Name","value":"active"}},{"kind":"Field","name":{"kind":"Name","value":"sourceUrl"}}]}},{"kind":"Field","name":{"kind":"Name","value":"errors"}}]}}]}}]} as unknown as DocumentNode<ApproveDashboardProductImportMutation, ApproveDashboardProductImportMutationVariables>;
/* eslint-disable */
import * as types from './graphql';
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';

/**
 * Map of all GraphQL operations in the project.
 *
 * This map has several performance disadvantages:
 * 1. It is not tree-shakeable, so it will include all operations in the project.
 * 2. It is not minifiable, so the string of a GraphQL query will be multiple times inside the bundle.
 * 3. It does not support dead code elimination, so it will add unused operations.
 *
 * Therefore it is highly recommended to use the babel or swc plugin for production.
 * Learn more about it here: https://the-guild.dev/graphql/codegen/plugins/presets/preset-client#reducing-bundle-size
 */
type Documents = {
    "query DashboardContext {\n  viewer {\n    id\n    name\n    email\n    role\n  }\n  currentBusiness {\n    id\n    name\n    slug\n    category\n    defaultLanguage\n    timezone\n    currency\n    status\n  }\n}\n\nquery DashboardAnalytics {\n  analytics {\n    conversations\n    uniqueCustomers\n    confirmedOrders\n    conversationToOrderRate\n    orderingCustomers\n    repeatCustomers\n    repeatCustomerRate\n    revenue\n    averageOrderValue\n    ordersByChannel\n    ordersByStatus\n    topProducts\n  }\n}\n\nquery DashboardProducts($first: Int = 50) {\n  products(first: $first) {\n    id\n    name\n    description\n    shortDescription\n    category\n    benefits\n    usageInstructions\n    suitableFor\n    productAttributes\n    price\n    stockQuantity\n    tags\n    active\n    wooCommerceProductId\n    variants {\n      id\n      name\n      size\n      sku\n      price\n      stockQuantity\n      active\n      position\n    }\n  }\n}\n\nmutation SaveDashboardProduct($id: ID, $input: ProductInput!) {\n  saveProduct(id: $id, input: $input) {\n    product {\n      id\n      name\n      description\n      shortDescription\n      category\n      benefits\n      usageInstructions\n      suitableFor\n      productAttributes\n      price\n      stockQuantity\n      tags\n      active\n      wooCommerceProductId\n      variants {\n        id\n        name\n        size\n        sku\n        price\n        stockQuantity\n        active\n        position\n      }\n    }\n    errors\n  }\n}": typeof types.DashboardContextDocument,
};
const documents: Documents = {
    "query DashboardContext {\n  viewer {\n    id\n    name\n    email\n    role\n  }\n  currentBusiness {\n    id\n    name\n    slug\n    category\n    defaultLanguage\n    timezone\n    currency\n    status\n  }\n}\n\nquery DashboardAnalytics {\n  analytics {\n    conversations\n    uniqueCustomers\n    confirmedOrders\n    conversationToOrderRate\n    orderingCustomers\n    repeatCustomers\n    repeatCustomerRate\n    revenue\n    averageOrderValue\n    ordersByChannel\n    ordersByStatus\n    topProducts\n  }\n}\n\nquery DashboardProducts($first: Int = 50) {\n  products(first: $first) {\n    id\n    name\n    description\n    shortDescription\n    category\n    benefits\n    usageInstructions\n    suitableFor\n    productAttributes\n    price\n    stockQuantity\n    tags\n    active\n    wooCommerceProductId\n    variants {\n      id\n      name\n      size\n      sku\n      price\n      stockQuantity\n      active\n      position\n    }\n  }\n}\n\nmutation SaveDashboardProduct($id: ID, $input: ProductInput!) {\n  saveProduct(id: $id, input: $input) {\n    product {\n      id\n      name\n      description\n      shortDescription\n      category\n      benefits\n      usageInstructions\n      suitableFor\n      productAttributes\n      price\n      stockQuantity\n      tags\n      active\n      wooCommerceProductId\n      variants {\n        id\n        name\n        size\n        sku\n        price\n        stockQuantity\n        active\n        position\n      }\n    }\n    errors\n  }\n}": types.DashboardContextDocument,
};

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 *
 *
 * @example
 * ```ts
 * const query = graphql(`query GetUser($id: ID!) { user(id: $id) { name } }`);
 * ```
 *
 * The query argument is unknown!
 * Please regenerate the types.
 */
export function graphql(source: string): unknown;

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "query DashboardContext {\n  viewer {\n    id\n    name\n    email\n    role\n  }\n  currentBusiness {\n    id\n    name\n    slug\n    category\n    defaultLanguage\n    timezone\n    currency\n    status\n  }\n}\n\nquery DashboardAnalytics {\n  analytics {\n    conversations\n    uniqueCustomers\n    confirmedOrders\n    conversationToOrderRate\n    orderingCustomers\n    repeatCustomers\n    repeatCustomerRate\n    revenue\n    averageOrderValue\n    ordersByChannel\n    ordersByStatus\n    topProducts\n  }\n}\n\nquery DashboardProducts($first: Int = 50) {\n  products(first: $first) {\n    id\n    name\n    description\n    shortDescription\n    category\n    benefits\n    usageInstructions\n    suitableFor\n    productAttributes\n    price\n    stockQuantity\n    tags\n    active\n    wooCommerceProductId\n    variants {\n      id\n      name\n      size\n      sku\n      price\n      stockQuantity\n      active\n      position\n    }\n  }\n}\n\nmutation SaveDashboardProduct($id: ID, $input: ProductInput!) {\n  saveProduct(id: $id, input: $input) {\n    product {\n      id\n      name\n      description\n      shortDescription\n      category\n      benefits\n      usageInstructions\n      suitableFor\n      productAttributes\n      price\n      stockQuantity\n      tags\n      active\n      wooCommerceProductId\n      variants {\n        id\n        name\n        size\n        sku\n        price\n        stockQuantity\n        active\n        position\n      }\n    }\n    errors\n  }\n}"): (typeof documents)["query DashboardContext {\n  viewer {\n    id\n    name\n    email\n    role\n  }\n  currentBusiness {\n    id\n    name\n    slug\n    category\n    defaultLanguage\n    timezone\n    currency\n    status\n  }\n}\n\nquery DashboardAnalytics {\n  analytics {\n    conversations\n    uniqueCustomers\n    confirmedOrders\n    conversationToOrderRate\n    orderingCustomers\n    repeatCustomers\n    repeatCustomerRate\n    revenue\n    averageOrderValue\n    ordersByChannel\n    ordersByStatus\n    topProducts\n  }\n}\n\nquery DashboardProducts($first: Int = 50) {\n  products(first: $first) {\n    id\n    name\n    description\n    shortDescription\n    category\n    benefits\n    usageInstructions\n    suitableFor\n    productAttributes\n    price\n    stockQuantity\n    tags\n    active\n    wooCommerceProductId\n    variants {\n      id\n      name\n      size\n      sku\n      price\n      stockQuantity\n      active\n      position\n    }\n  }\n}\n\nmutation SaveDashboardProduct($id: ID, $input: ProductInput!) {\n  saveProduct(id: $id, input: $input) {\n    product {\n      id\n      name\n      description\n      shortDescription\n      category\n      benefits\n      usageInstructions\n      suitableFor\n      productAttributes\n      price\n      stockQuantity\n      tags\n      active\n      wooCommerceProductId\n      variants {\n        id\n        name\n        size\n        sku\n        price\n        stockQuantity\n        active\n        position\n      }\n    }\n    errors\n  }\n}"];

export function graphql(source: string) {
  return (documents as any)[source] ?? {};
}

export type DocumentType<TDocumentNode extends DocumentNode<any, any>> = TDocumentNode extends DocumentNode<  infer TType,  any>  ? TType  : never;
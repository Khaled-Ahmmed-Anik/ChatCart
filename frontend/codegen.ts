import type { CodegenConfig } from "@graphql-codegen/cli";

const config: CodegenConfig = {
  schema: "../backend/schema.graphql",
  documents: ["src/graphql/**/*.graphql"],
  generates: {
    "src/graphql/generated/": {
      preset: "client",
      presetConfig: { fragmentMasking: false }
    }
  },
  ignoreNoDocuments: false
};

export default config;

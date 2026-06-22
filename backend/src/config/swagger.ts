import fs from "fs";
import path from "path";
import YAML from "yaml";

const specPath = path.join(__dirname, "..", "..", "docs", "openapi.yaml");

export const openapiSpec: object = YAML.parse(fs.readFileSync(specPath, "utf8"));

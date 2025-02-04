//
// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#ifndef ZETASQL_TESTDATA_TVF_WITH_USER_ID_H_
#define ZETASQL_TESTDATA_TVF_WITH_USER_ID_H_

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "zetasql/public/catalog.h"
#include "zetasql/public/table_valued_function.h"
#include "absl/algorithm/container.h"

namespace zetasql {

// Helper classes for testing TVFs with anonymization metadata. Used by the
// SampleCatalog for (broken link). An AnonymizationInfo
// instance is created from a provided user identifier column name.
class TVFSignatureWithUid : public TVFSignature {
 public:
  TVFSignatureWithUid(const std::vector<TVFInputArgumentType>& input_arguments,
                      const TVFRelation& result_schema,
                      const std::string& uid_column_name)
      : TVFSignature(input_arguments, result_schema) {
    ZETASQL_CHECK(absl::c_any_of(result_schema.columns(),
                         [&uid_column_name](const TVFSchemaColumn& col) {
                           return col.name == uid_column_name;
                         }));
    anon_info_ = AnonymizationInfo::Create({uid_column_name}).ValueOrDie();
  }

  std::optional<const AnonymizationInfo> GetAnonymizationInfo() const override {
    return *anon_info_;
  }

 private:
  std::unique_ptr<AnonymizationInfo> anon_info_;
};

class FixedOutputSchemaTVFWithUid : public FixedOutputSchemaTVF {
 public:
  // Constructs a new TVF object with the given name and fixed output schema.
  FixedOutputSchemaTVFWithUid(
      const std::vector<std::string>& function_name_path,
      const FunctionSignature& signature, const TVFRelation& result_schema,
      const std::string uid_column_name)
      : FixedOutputSchemaTVF(function_name_path, signature, result_schema),
        result_schema_(result_schema),
        uid_column_name_(uid_column_name) {}

  absl::Status Resolve(
      const AnalyzerOptions* analyzer_options,
      const std::vector<TVFInputArgumentType>& actual_arguments,
      const FunctionSignature& concrete_signature, Catalog* catalog,
      TypeFactory* type_factory,
      std::shared_ptr<TVFSignature>* tvf_signature) const override {
    tvf_signature->reset(new TVFSignatureWithUid(
        actual_arguments, result_schema_, uid_column_name_));
    return absl::OkStatus();
  }

 private:
  const TVFRelation result_schema_;
  const std::string uid_column_name_;
};

}  // namespace zetasql

#endif  // ZETASQL_TESTDATA_TVF_WITH_USER_ID_H_

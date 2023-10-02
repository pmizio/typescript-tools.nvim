[
  (class_declaration name: (_) @declaration)
  (export_statement
    (_ kind: ["const" "let"] (variable_declarator name: (_) @declaration)))
  (_ body: [
    (class_body [
      (method_definition name: (_) @member)
      (field_definition property: (property_identifier) @member)
    ])
  ])
]

[
  (class_declaration name: (_) @name)
  (export_statement
    (_ kind: ["const" "let"] (variable_declarator name: (_) @name)))
  (_ body: [
    (class_body [
      (method_definition name: (_) @name)
      (field_definition property: (property_identifier) @name)
    ])
  ])
]

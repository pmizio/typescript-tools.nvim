[
  (interface_declaration name: (_) @name)
  (type_alias_declaration name: (_) @name)
  (abstract_class_declaration name: (_) @name)
  (class_declaration name: (_) @name)
  (enum_declaration name: (_) @name)
  (export_statement
    (_ kind: ["const" "let"] (variable_declarator name: (_) @name)))
  (_ body: [
    (enum_body [
      (property_identifier) @name
      (_ name: (property_identifier) @name)
    ])
    (class_body [
      (method_definition name: (_) @name)
      (public_field_definition name: (_) @name)
    ])
    (object_type [
      (method_signature name: (_) @name)
      (property_signature
        name: (_) @name
        type: (type_annotation (function_type)))
    ])
  ])
  (type_alias_declaration value: (object_type [
    (method_signature name: (_) @name)
    (property_signature
      name: (_) @name
      type: (type_annotation (function_type)))
  ]))
]

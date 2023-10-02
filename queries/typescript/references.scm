[
  (interface_declaration name: (_) @declaration)
  (type_alias_declaration name: (_) @declaration)
  (abstract_class_declaration name: (_) @declaration)
  (class_declaration name: (_) @declaration)
  (enum_declaration name: (_) @declaration)
  (export_statement
    (_ kind: ["const" "let"] (variable_declarator name: (_) @declaration)))
  (_ body: [
    (enum_body [
      (property_identifier) @member
      (_ name: (property_identifier) @member)
    ])
    (class_body [
      (method_definition name: (_) @member)
      (public_field_definition name: (_) @member)
    ])
    (object_type [
      (method_signature name: (_) @member)
      (property_signature
        name: (_) @member
        type: (type_annotation (function_type)))
    ])
  ])
  (type_alias_declaration value: (object_type [
    (method_signature name: (_) @member)
    (property_signature
      name: (_) @member
      type: (type_annotation (function_type)))
  ]))
]

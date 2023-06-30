async function foo() {
  const y = 0;
  return 1;
}

function bar() {
  const y = export1;
  const f = await foo();
  return f;
}

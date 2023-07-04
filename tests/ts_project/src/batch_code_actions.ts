async function foo() {
  const unused = 0;
  return 1;
}

function bar() {
  const unused = export1;
  const f = await foo();
  return f;
}

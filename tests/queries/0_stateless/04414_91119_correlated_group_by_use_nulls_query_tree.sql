-- https://github.com/ClickHouse/ClickHouse/issues/91119
--
-- Type-level regression test for the analyzer fix in correlated subqueries under
-- `group_by_use_nulls = 1`. The existing `04210_91119_*` test only checks query
-- results; this one pins the `result_type` the analyzer assigns, which is the exact
-- behaviour the fix changes. `EXPLAIN QUERY TREE` is filtered to the type-bearing
-- lines and node ids are normalised so the reference is stable.
--
-- A correlated reference to an outer `GROUP BY` key must become `Nullable` (the key is
-- nulled out in `ROLLUP`/`CUBE`/`GROUPING SETS` extra rows), while the outer `GROUP BY`
-- key node itself and aggregate-function arguments (which see real data rows) must stay
-- non-`Nullable`.

SET enable_analyzer = 1;
SET allow_experimental_correlated_subqueries = 1;
SET group_by_use_nulls = 1;

-- A bare correlated column must be Nullable inside the correlated subquery, while the
-- outer GROUP BY key node keeps its plain type.
SELECT '-- bare correlated column ---';
SELECT replaceRegexpAll(trim(explain), 'id: [0-9]+', 'id: N') AS line
FROM (EXPLAIN QUERY TREE
    SELECT (SELECT c) FROM (SELECT toInt32(3) AS c) t GROUP BY c WITH ROLLUP)
WHERE explain ILIKE '%column_name: c,%result_type%';

-- A compound GROUP BY key (modulo) is the case that blocked the earlier revision: the
-- whole correlated expression must be wrapped, not just a bare column source.
SELECT '-- compound correlated key (modulo) ---';
SELECT replaceRegexpAll(trim(explain), 'id: [0-9]+', 'id: N') AS line
FROM (EXPLAIN QUERY TREE
    SELECT (SELECT c % 2) FROM (SELECT toInt32(3) AS c) t GROUP BY c % 2 WITH ROLLUP)
WHERE explain ILIKE '%function_name: modulo%result_type%';

-- An aggregate-function argument processes real data rows, not rollup-total rows, so the
-- GROUP BY key used inside it must stay non-Nullable.
SELECT '-- aggregate argument stays non-Nullable ---';
SELECT replaceRegexpAll(trim(explain), 'id: [0-9]+', 'id: N') AS line
FROM (EXPLAIN QUERY TREE
    SELECT * APPLY x -> argMax(x, number) FROM numbers(1) GROUP BY number WITH ROLLUP)
WHERE explain ILIKE '%column_name: number,%result_type%';

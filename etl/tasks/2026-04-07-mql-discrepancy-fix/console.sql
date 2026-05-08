USE ROLE TRANSFORMER;

DELETE FROM soundstripe_prod.TRANSFORMATIONS.fct_sessions_build
WHERE session_started_at >= '2026-02-23';
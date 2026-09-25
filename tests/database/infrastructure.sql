-- Infrastructure fixtures only: not community/product tables or permissions.
CREATE SCHEMA infrastructure_fixture;
REVOKE ALL ON SCHEMA infrastructure_fixture FROM PUBLIC;
CREATE TABLE infrastructure_fixture.counter (
  id integer PRIMARY KEY,
  value integer NOT NULL CHECK (value >= 0)
);
INSERT INTO infrastructure_fixture.counter VALUES (1, 0);
BEGIN;
UPDATE infrastructure_fixture.counter SET value = 99 WHERE id = 1;
ROLLBACK;
DO $$
BEGIN
  IF (SELECT value FROM infrastructure_fixture.counter WHERE id = 1) <> 0 THEN
    RAISE EXCEPTION 'Rollback failed';
  END IF;
  BEGIN
    INSERT INTO infrastructure_fixture.counter VALUES (1, 5);
    RAISE EXCEPTION 'Duplicate key unexpectedly accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END
$$;

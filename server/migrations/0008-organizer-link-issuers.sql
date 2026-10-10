-- A delegated organizer link must close when its issuing account loses management.
ALTER TABLE ca_profile_link ADD COLUMN issuer_id text REFERENCES "user"(id) ON DELETE CASCADE;
UPDATE ca_profile_link l SET issuer_id=p.owner_id FROM ca_organizer p WHERE l.profile_id=p.id;
ALTER TABLE ca_profile_link ALTER COLUMN issuer_id SET NOT NULL;

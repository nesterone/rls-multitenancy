-- Create a table for our tenants with indexes on the primary key and the tenant’s name
CREATE TABLE tenant
(
    tenant_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name      VARCHAR(255) UNIQUE,
    status    VARCHAR(64) CHECK (status IN ('active', 'suspended', 'disabled')),
    tier      VARCHAR(64) CHECK (tier IN ('gold', 'silver', 'bronze'))
);

-- Create a table for users of a tenant
CREATE TABLE tenant_user
(
    user_id     UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    tenant_id   UUID         NOT NULL REFERENCES tenant (tenant_id) ON DELETE RESTRICT,
    email       VARCHAR(255) NOT NULL UNIQUE,
    given_name  VARCHAR(255) NOT NULL CHECK (given_name <> ''),
    family_name VARCHAR(255) NOT NULL CHECK (family_name <> '')
);

-- Turn on RLS
ALTER TABLE tenant ENABLE ROW LEVEL SECURITY;

-- Restrict read and write actions so tenants can only see their rows
-- Cast the UUID value in tenant_id to match the type current_user returns
-- This policy implies a WITH CHECK that matches the USING clause
CREATE POLICY tenant_isolation_policy ON tenant
USING (tenant_id::UUID = current_setting('app.current_tenant')::UUID);

-- And do the same for the tenant users
ALTER TABLE tenant_user ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_user_isolation_policy ON tenant_user
USING (tenant_id::UUID = current_setting('app.current_tenant'));

-- Create two tenants `foo` and `bar`
INSERT INTO tenant (name, status, tier)
VALUES ('foo', 'active', 'gold');

INSERT INTO tenant (name, status, tier)
VALUES ('bar', 'active', 'silver');

-- Get tenant's ids
SELECT tenant_id from tenant where name = 'foo';
SELECT tenant_id  from tenant where name = 'bar';

-- Copy past tenant ids
-- Add `Joe Doe` and `Bob Strong` to `foo` tenant
INSERT INTO tenant_user (tenant_id, email, given_name, family_name)
VALUES ('bf4b5d7c-6bdb-420d-bec2-a89722954f5e', 'joe@email.com', 'Joe', 'Doe');

INSERT INTO tenant_user (tenant_id, email, given_name, family_name)
VALUES ('bf4b5d7c-6bdb-420d-bec2-a89722954f5e', 'bob@email.com', 'Bob', 'Strong');

--Add `Luck Iron` and `Hot Water` to `bar` tenant
INSERT INTO tenant_user (tenant_id, email, given_name, family_name)
VALUES ('f7d70ae6-9d77-4e84-ba2f-fd8e3872f31b', 'luck@email.com', 'Luck', 'Iron');

INSERT INTO tenant_user (tenant_id, email, given_name, family_name)
VALUES ('f7d70ae6-9d77-4e84-ba2f-fd8e3872f31b', 'hot@email.com', 'Hot', 'Water');

-- Create org user
create user org_user with password 'org_user';
grant all on tenant, tenant_user to org_user;


-- Login with org user
-- \c rls-tenants org_user;
--- Select `foo` as current tenant
SET app.current_tenant = 'bf4b5d7c-6bdb-420d-bec2-a89722954f5e';

--  Check setting
SELECT (current_setting('app.current_tenant'::text)::uuid);

-- Should find only foo tenant
SELECT * from tenant;

-- Should find only 'Joe' and 'Bob'
SELECT * from tenant_user;
-- Create the database if it doesn't exist
CREATE DATABASE smarthome;

-- Connect to the database
\c smarthome;

-- Create the sync sensors table
CREATE TABLE IF NOT EXISTS sensors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    location VARCHAR(100) NOT NULL,
    value FLOAT DEFAULT 0,
    unit VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'inactive',
    last_updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_sensors_type ON sensors(type);
CREATE INDEX IF NOT EXISTS idx_sensors_location ON sensors(location);
CREATE INDEX IF NOT EXISTS idx_sensors_status ON sensors(status);

CREATE TABLE IF NOT EXISTS UserTypes (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL
);

INSERT INTO UserTypes (name) VALUES 
    ('client'),
    ('partner'),
    ('employee');

CREATE TABLE IF NOT EXISTS Users (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    password TEXT NOT NULL,
    token TEXT NOT NULL,
    usertype_uid UUID NOT NULL REFERENCES UserTypes(uid)
);

INSERT INTO Users (name, email, phone, password, token, usertype_uid)
SELECT 
    'Client_' || i,
    'client' || i || '@example.com',
    '+7-900-' || LPAD(i::TEXT, 3, '0') || '-12-34',
    MD5('password' || i),
    MD5(gen_random_uuid()::TEXT),
    (SELECT uid FROM UserTypes WHERE name = 'client')
FROM GENERATE_SERIES(1, 1000) AS i;

INSERT INTO Users (name, email, phone, password, token, usertype_uid)
SELECT 
    'Partner_' || i,
    'partner' || i || '@example.com',
    '+7-901-' || LPAD(i::TEXT, 3, '0') || '-56-78',
    MD5('partnerpass' || i),
    MD5(gen_random_uuid()::TEXT),
    (SELECT uid FROM UserTypes WHERE name = 'partner')
FROM GENERATE_SERIES(1, 25) AS i;

INSERT INTO Users (name, email, phone, password, token, usertype_uid)
SELECT 
    'Employee_' || i,
    'employee' || i || '@company.com',
    '+7-902-' || LPAD(i::TEXT, 3, '0') || '-90-12',
    MD5('emppass' || i),
    MD5(gen_random_uuid()::TEXT),
    (SELECT uid FROM UserTypes WHERE name = 'employee')
FROM GENERATE_SERIES(1, 5) AS i;

CREATE TABLE Services (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL
);

INSERT INTO Services (name) VALUES
    ('Module Repair'),
    ('Module Replacement'),
    ('Module Installation'),
    ('Module Configuration'),
    ('Warranty Case'),
    ('Module Purchase with Delivery');

CREATE TABLE PartnerServices (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uid UUID NOT NULL REFERENCES Users(uid),
    service_uid UUID NOT NULL REFERENCES Services(uid),
    coast NUMERIC(10,2)
);

WITH 
partners AS (
    SELECT uid
    FROM Users
    WHERE usertype_uid = (SELECT uid FROM UserTypes WHERE name = 'partner')
    ORDER BY random()
    LIMIT 20
),
partner_random_count AS (
    SELECT 
        p.uid AS partner_uid,
        floor(random() * 6 + 1)::int AS num_services
    FROM partners p
),
partner_services_ranked AS (
    SELECT 
        prc.partner_uid,
        s.uid AS service_uid,
        row_number() OVER (PARTITION BY prc.partner_uid ORDER BY random()) AS rn,
        prc.num_services
    FROM partner_random_count prc
    CROSS JOIN Services s
),
selected_services AS (
    SELECT partner_uid, service_uid
    FROM partner_services_ranked
    WHERE rn <= num_services
),
final_insert AS (
    SELECT 
        ss.partner_uid,
        ss.service_uid,
        round((random() * 49000 + 1000)::numeric, 2) AS coast
    FROM selected_services ss
)
INSERT INTO PartnerServices (user_uid, service_uid, coast)
SELECT partner_uid, service_uid, coast
FROM final_insert;

CREATE TABLE PartnerModule (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    user_uid UUID NOT NULL REFERENCES Users(uid),
    description TEXT,
    date_release TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_available BOOLEAN
);

WITH
partners AS (
    SELECT DISTINCT user_uid
    FROM PartnerServices
),
partner_counts AS (
    SELECT 
        user_uid,
        floor(random() * 6 + 5)::int AS num_services
    FROM partners
),
expanded AS (
    SELECT 
        pc.user_uid,
        generate_series(1, pc.num_services) AS idx
    FROM partner_counts pc
)
INSERT INTO PartnerModule (user_uid, name, description, is_available, date_release)
SELECT 
    e.user_uid,
    'Module for partner ' || e.user_uid || ' #' || e.idx,
    CASE WHEN random() < 0.5 THEN 'High quality module' ELSE 'Standard module' END,
    random() < 0.8,
    CURRENT_TIMESTAMP - (random() * interval '180 days')
FROM expanded e;

CREATE TABLE Orders (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL,
    user_uid UUID NOT NULL REFERENCES Users(uid),
    partner_service_uid UUID NOT NULL REFERENCES PartnerServices(uid),
    is_done BOOLEAN
);


WITH
random_clients AS (
    SELECT uid
    FROM Users
    WHERE usertype_uid = (SELECT uid FROM UserTypes WHERE name = 'client')
    ORDER BY random()
    LIMIT 495
),
numbered_clients AS (
    SELECT uid, ROW_NUMBER() OVER () AS rn
    FROM random_clients
),
client_orders AS (
    SELECT 
        uid,
        CASE WHEN rn <= 450 THEN 1 ELSE 2 END AS num_orders
    FROM numbered_clients
),
expanded AS (
    SELECT 
        uid AS user_uid,
        generate_series(1, num_orders) AS order_seq
    FROM client_orders
),
service_array AS (
    SELECT array_agg(uid) AS ids, count(*) AS cnt
    FROM PartnerServices
)
INSERT INTO Orders (user_uid, partner_service_uid, description, is_done)
SELECT 
    e.user_uid,
    (sa.ids)[1 + floor(random() * sa.cnt)::int] AS partner_service_uid,
    ROW_NUMBER() OVER ()::TEXT AS description,
    random() < 0.5 AS is_done
FROM expanded e
CROSS JOIN service_array sa;

CREATE TABLE Houses (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uid UUID NOT NULL REFERENCES Users(uid),
    address TEXT NOT NULL
);

WITH
addresses AS (
    SELECT 'Street ' || s || ' house ' || h AS full_address
    FROM generate_series(1,10) s
    CROSS JOIN generate_series(1,50) h
),
users_500 AS (
    SELECT uid, ROW_NUMBER() OVER (ORDER BY random()) AS rn
    FROM Users
    LIMIT 500
),
first_houses AS (
    SELECT 
        u.uid AS user_uid,
        (SELECT full_address FROM addresses ORDER BY random() LIMIT 1) AS address
    FROM users_500 u
),
extra_users AS (
    SELECT uid
    FROM users_500
    ORDER BY random()
    LIMIT 25
),
extra_counts AS (
    SELECT 
        uid,
        CASE WHEN random() < 0.5 THEN 1 ELSE 2 END AS extra_house_count
    FROM extra_users
),
extra_houses AS (
    SELECT 
        ec.uid AS user_uid,
        generate_series(1, ec.extra_house_count) AS n,
        (SELECT full_address FROM addresses ORDER BY random() LIMIT 1) AS address
    FROM extra_counts ec
)
INSERT INTO Houses (user_uid, address)
SELECT user_uid, address FROM first_houses
UNION ALL
SELECT user_uid, address FROM extra_houses;


CREATE TABLE Modules (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_uid UUID NOT NULL REFERENCES Houses(uid),
    name TEXT NOT NULL,
    serial_number TEXT NOT NULL,
    relay_status BOOLEAN,
    register_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

WITH
houses_random AS (
    SELECT 
        uid,
        random() AS r_count,
        random() AS r_name, 
        random() AS r_relay,
        random() AS r_date  
    FROM Houses
)
INSERT INTO Modules (house_uid, name, serial_number, relay_status, register_date)
SELECT 
    h.uid,
    (ARRAY[
        'Module_A', 'Module_B', 'Module_C', 'Module_D', 'Module_E',
        'Module_F', 'Module_G', 'Module_H', 'Module_I', 'Module_J'
    ])[1 + floor(h.r_name * 10)],
    'SN-' || floor(random() * 1000000)::text,
    h.r_relay < 0.8,
    CURRENT_TIMESTAMP - (h.r_date * interval '180 days')
FROM houses_random h
CROSS JOIN LATERAL generate_series(1, (1 + floor(h.r_count * 3))::int) AS gs;


CREATE TABLE MarketingCampaign (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uid UUID NOT NULL REFERENCES Users(uid),
    description TEXT,
    start_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    stop_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

WITH
random_modules AS (
    SELECT uid AS module_uid, house_uid
    FROM Modules
    ORDER BY random()
    LIMIT 3
),
module_owners AS (
    SELECT rm.module_uid, h.user_uid
    FROM random_modules rm
    JOIN Houses h ON rm.house_uid = h.uid
)

INSERT INTO MarketingCampaign (user_uid, description, start_date, stop_date)
SELECT 
    mo.user_uid,
    'Special offer on the module ' || m.name,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP + (random() * interval '30 days')
FROM module_owners mo
JOIN Modules m ON mo.module_uid = m.uid;

CREATE TABLE AsyncSensorTypes (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL
);

INSERT INTO AsyncSensorTypes (name) VALUES
    ('Heating'),
    ('Light control'),
    ('Automatic gates'),
    ('Remote monitoring'),
    ('Future unspecified behavior');

CREATE TABLE AsyncSensors (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID NOT NULL REFERENCES Modules(uid),
    name VARCHAR(100) NOT NULL,
    type_uid UUID NOT NULL REFERENCES AsyncSensorTypes(uid),
    location VARCHAR(100) NOT NULL,
    serial_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'inactive',
    last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


WITH
type_array AS (
    SELECT array_agg(uid) AS ids
    FROM AsyncSensorTypes
),
modules_with_count AS (
    SELECT 
        uid AS module_uid,
        (1 + floor(random() * 4))::int AS sensor_count
    FROM Modules
),
sensor_rows AS (
    SELECT 
        mwc.module_uid,
        generate_series(1, mwc.sensor_count) AS sensor_idx,
        ta.ids
    FROM modules_with_count mwc
    CROSS JOIN type_array ta
)
INSERT INTO AsyncSensors (module_id, name, type_uid, location, serial_number, status, last_updated, created_at)
SELECT 
    sr.module_uid,
    'Sensor ' || sr.sensor_idx || ' of module ' || sr.module_uid::text,
    sr.ids[1 + floor(random() * array_length(sr.ids, 1))],
    (ARRAY['Living room', 'Kitchen', 'Bedroom', 'Outside', 'Hallway'])[1 + floor(random() * 5)],
    'SN-SENS-' || substr(md5(random()::text), 1, 8) || '-' || sr.sensor_idx,
    CASE WHEN random() < 0.7 THEN 'active' ELSE 'inactive' END,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM sensor_rows sr;
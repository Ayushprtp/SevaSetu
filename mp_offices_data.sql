-- ============================================
-- MADHYA PRADESH DISTRICT OFFICES DATA
-- ============================================

-- BHOPAL DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Bhopal Division', 'pwd', 'Bhopal', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(77.4126, 23.2599), 4326)::geography, false, 'pwd.bhopal@mp.gov.in', '0755-2551234'),
('Bhopal Municipal Corporation - Sanitation', 'sanitation', 'Bhopal', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(77.4009, 23.2332), 4326)::geography, false, 'sanitation.bmc@mp.gov.in', '0755-2552345'),
('MPEB Bhopal Circle', 'electricity', 'Bhopal', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(77.4350, 23.2500), 4326)::geography, false, 'mpeb.bhopal@mp.gov.in', '0755-2553456'),
('PHED Bhopal Division', 'water', 'Bhopal', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(77.4200, 23.2400), 4326)::geography, false, 'phed.bhopal@mp.gov.in', '0755-2554567'),
('District Collector Office Bhopal', 'general', 'Bhopal', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(77.4126, 23.2599), 4326)::geography, false, 'collector.bhopal@mp.gov.in', '0755-2555678');

-- INDORE DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Indore Division', 'pwd', 'Indore', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.8577, 22.7196), 4326)::geography, false, 'pwd.indore@mp.gov.in', '0731-2551234'),
('Indore Municipal Corporation - Sanitation', 'sanitation', 'Indore', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.8500, 22.7100), 4326)::geography, false, 'sanitation.imc@mp.gov.in', '0731-2552345'),
('MPEB Indore Circle', 'electricity', 'Indore', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.8650, 22.7250), 4326)::geography, false, 'mpeb.indore@mp.gov.in', '0731-2553456'),
('PHED Indore Division', 'water', 'Indore', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.8600, 22.7150), 4326)::geography, false, 'phed.indore@mp.gov.in', '0731-2554567'),
('District Collector Office Indore', 'general', 'Indore', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.8577, 22.7196), 4326)::geography, false, 'collector.indore@mp.gov.in', '0731-2555678');

-- GWALIOR DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Gwalior Division', 'pwd', 'Gwalior', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.1828, 26.2183), 4326)::geography, false, 'pwd.gwalior@mp.gov.in', '0751-2551234'),
('Gwalior Municipal Corporation - Sanitation', 'sanitation', 'Gwalior', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.1750, 26.2100), 4326)::geography, false, 'sanitation.gmc@mp.gov.in', '0751-2552345'),
('MPEB Gwalior Circle', 'electricity', 'Gwalior', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.1900, 26.2250), 4326)::geography, false, 'mpeb.gwalior@mp.gov.in', '0751-2553456'),
('PHED Gwalior Division', 'water', 'Gwalior', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.1850, 26.2150), 4326)::geography, false, 'phed.gwalior@mp.gov.in', '0751-2554567'),
('District Collector Office Gwalior', 'general', 'Gwalior', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.1828, 26.2183), 4326)::geography, false, 'collector.gwalior@mp.gov.in', '0751-2555678');

-- JABALPUR DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Jabalpur Division', 'pwd', 'Jabalpur', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(79.9864, 23.1815), 4326)::geography, false, 'pwd.jabalpur@mp.gov.in', '0761-2551234'),
('Jabalpur Municipal Corporation - Sanitation', 'sanitation', 'Jabalpur', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(79.9800, 23.1750), 4326)::geography, false, 'sanitation.jmc@mp.gov.in', '0761-2552345'),
('MPEB Jabalpur Circle', 'electricity', 'Jabalpur', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(79.9950, 23.1900), 4326)::geography, false, 'mpeb.jabalpur@mp.gov.in', '0761-2553456'),
('PHED Jabalpur Division', 'water', 'Jabalpur', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(79.9900, 23.1850), 4326)::geography, false, 'phed.jabalpur@mp.gov.in', '0761-2554567'),
('District Collector Office Jabalpur', 'general', 'Jabalpur', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(79.9864, 23.1815), 4326)::geography, false, 'collector.jabalpur@mp.gov.in', '0761-2555678');

-- UJJAIN DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Ujjain Division', 'pwd', 'Ujjain', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.7885, 23.1765), 4326)::geography, false, 'pwd.ujjain@mp.gov.in', '0734-2551234'),
('Ujjain Municipal Corporation - Sanitation', 'sanitation', 'Ujjain', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.7800, 23.1700), 4326)::geography, false, 'sanitation.umc@mp.gov.in', '0734-2552345'),
('MPEB Ujjain Circle', 'electricity', 'Ujjain', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.7950, 23.1850), 4326)::geography, false, 'mpeb.ujjain@mp.gov.in', '0734-2553456'),
('PHED Ujjain Division', 'water', 'Ujjain', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.7900, 23.1800), 4326)::geography, false, 'phed.ujjain@mp.gov.in', '0734-2554567'),
('District Collector Office Ujjain', 'general', 'Ujjain', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(75.7885, 23.1765), 4326)::geography, false, 'collector.ujjain@mp.gov.in', '0734-2555678');

-- SAGAR DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Sagar Division', 'pwd', 'Sagar', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.7378, 23.8388), 4326)::geography, false, 'pwd.sagar@mp.gov.in', '07582-251234'),
('Sagar Municipal Corporation - Sanitation', 'sanitation', 'Sagar', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.7300, 23.8300), 4326)::geography, false, 'sanitation.smc@mp.gov.in', '07582-252345'),
('MPEB Sagar Circle', 'electricity', 'Sagar', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.7450, 23.8450), 4326)::geography, false, 'mpeb.sagar@mp.gov.in', '07582-253456'),
('PHED Sagar Division', 'water', 'Sagar', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.7400, 23.8400), 4326)::geography, false, 'phed.sagar@mp.gov.in', '07582-254567'),
('District Collector Office Sagar', 'general', 'Sagar', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(78.7378, 23.8388), 4326)::geography, false, 'collector.sagar@mp.gov.in', '07582-255678');

-- REWA DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Rewa Division', 'pwd', 'Rewa', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(81.3037, 24.5373), 4326)::geography, false, 'pwd.rewa@mp.gov.in', '07662-251234'),
('Rewa Municipal Corporation - Sanitation', 'sanitation', 'Rewa', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(81.2950, 24.5300), 4326)::geography, false, 'sanitation.rmc@mp.gov.in', '07662-252345'),
('MPEB Rewa Circle', 'electricity', 'Rewa', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(81.3100, 24.5450), 4326)::geography, false, 'mpeb.rewa@mp.gov.in', '07662-253456'),
('PHED Rewa Division', 'water', 'Rewa', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(81.3050, 24.5400), 4326)::geography, false, 'phed.rewa@mp.gov.in', '07662-254567'),
('District Collector Office Rewa', 'general', 'Rewa', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(81.3037, 24.5373), 4326)::geography, false, 'collector.rewa@mp.gov.in', '07662-255678');

-- SATNA DISTRICT OFFICES
INSERT INTO offices (name, department, district, state, location, is_state_level, contact_email, contact_phone)
VALUES 
('PWD Satna Division', 'pwd', 'Satna', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(80.8322, 24.6005), 4326)::geography, false, 'pwd.satna@mp.gov.in', '07672-251234'),
('Satna Municipal Corporation - Sanitation', 'sanitation', 'Satna', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(80.8250, 24.5950), 4326)::geography, false, 'sanitation.satna@mp.gov.in', '07672-252345'),
('MPEB Satna Circle', 'electricity', 'Satna', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(80.8400, 24.6100), 4326)::geography, false, 'mpeb.satna@mp.gov.in', '07672-253456'),
('PHED Satna Division', 'water', 'Satna', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(80.8350, 24.6050), 4326)::geography, false, 'phed.satna@mp.gov.in', '07672-254567'),
('District Collector Office Satna', 'general', 'Satna', 'Madhya Pradesh', ST_SetSRID(ST_MakePoint(80.8322, 24.6005), 4326)::geography, false, 'collector.satna@mp.gov.in', '07672-255678');

-- Verify insertion
SELECT department, COUNT(*) as count FROM offices GROUP BY department ORDER BY department;
SELECT district, COUNT(*) as count FROM offices WHERE state = 'Madhya Pradesh' GROUP BY district ORDER BY district;

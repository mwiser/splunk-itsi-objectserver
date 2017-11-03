drop trigger itsi_integration;
go
drop procedure itsi_integration;
go
drop trigger group splunk_triggers;
go
create or replace procedure itsi_integration (in FirstOccurrence UTC, in LastOccurrence UTC, in Acknowledged Integer, in Identifier Char(255), in ServerName Char(64), in ServerSerial Integer, in AlertGroup Char(255), in Severity Integer, in Node Char(64), in Summary Char(255), in AlertKey Char(255)) executable '/opt/IBM/tivoli/netcool/omnibus/itsi/itsi_integration.pl' host  '10.199.228.164'  user 29000 group 29000 arguments 'title', '\"'+AlertGroup+'\"',
'host', '\"'+Node+'\"',
'description', '\"'+Summary+'\"',
'severname', '\"'+ServerName+'\"',
'identifier', '\"'+Identifier+'\"',
'alertkey', '\"'+AlertKey+'\"',
'severity', Severity,
'firstoccurrence' ,FirstOccurrence,
'lastoccurrence' ,LastOccurrence,
'status', Acknowledged,
'serverserial', ServerSerial
go

create or replace trigger group splunk_triggers;
go
create or replace trigger itsi_integration
group splunk_triggers
debug true
priority 1
comment 'Use Integration to dispatch an event to Splunk ITSI'
every 15 seconds
begin
        cancel;
end;
go
create or replace trigger itsi_integration
group splunk_triggers
debug true
priority 1
comment 'Use Integration to dispatch an event to Splunk ITSI'
every 15 seconds
when (get_prop_value( 'BackupObjectServer' ) %= 'FALSE') and
(get_prop_value( 'ActingPrimary' ) %= 'TRUE')
declare itsi_severity int;
begin

-- Select all the rows in alerts.status which should be sent to ITSI
for each row r in alerts.status where  r.StateChange >= (getdate() - 15)
  begin
    set itsi_severity = r.Severity+1;

    execute itsi_integration(r.FirstOccurrence,r.LastOccurrence,r.Acknowledged,r.Identifier, r.ServerName, r.ServerSerial, r.AlertGroup, itsi_severity, r.Node, r.Summary, r.AlertKey);

  end;
end;
go

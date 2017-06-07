<?xml version="1.0" encoding="iso-8859-1" standalone="no"?>
<Package DatabaseKind="KB_CENTRAL" Description="Delta Snapshot" Display="Delta Snapshot" PackName="DELTA_SNAPSHOT" SupportedServer="ALL" Type="SPECIFIC" Version="1.0.0.1000">
	<Include>
	</Include>
	<Exclude>
	</Exclude>
	<Install>
    <!-- Do not recreate the tables of the scope DELTA_SNAPSHOT to avoid losing data -->
		<Step File="table_delta_snapshot.xml" Option="512" Scope="DELTA_SNAPSHOT" Type="XML_MODEL"/>
    <!-- Avoid recreating the tables of the scope DELTA_SNAPSHOT_QR to avoid having to re-install each extension which injects the data with the XML -->
		<Step File="table_delta_snapshot.xml" Option="512" Scope="DELTA_SNAPSHOT_QR" Type="XML_MODEL"/>
	</Install>
	<Update>
	</Update>
	<Refresh>
		<Step File="DeltaSnapshot.sql" Type="PROC"/>
	</Refresh>
	<Remove>
	</Remove>
</Package>

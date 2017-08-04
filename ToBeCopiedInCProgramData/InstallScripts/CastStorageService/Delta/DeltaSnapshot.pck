<?xml version="1.0" encoding="iso-8859-1" standalone="no"?>
<Package DatabaseKind="KB_CENTRAL" Description="Delta Snapshot" Display="Delta Snapshot" PackName="DELTA_SNAPSHOT" SupportedServer="ALL" Type="SPECIFIC" Version="1.1.0">
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
		<Step File="table_delta_snapshot.xml" Option="512" Scope="DELTA_SNAPSHOT_QR" Type="XML_MODEL" ToVersion="1.0.1"/>
		<Step File="table_delta_snapshot.xml" Option="512" Scope="DELTA_SNAPSHOT_1.1.0" Type="XML_MODEL" ToVersion="1.1.0"/>
		<Step File="table_delta_snapshot.xml" Option="512" Scope="DELTA_SNAPSHOT_1.2.0" Type="XML_MODEL" ToVersion="1.2.0"/>
	</Update>
	<Refresh>
    <!-- Index -->
		<Step File="table_delta_snapshot.xml" Option="256" Scope="DELTA_SNAPSHOT" Type="XML_MODEL"/>
    <!-- Index -->
		<Step File="table_delta_snapshot.xml" Option="256" Scope="DELTA_SNAPSHOT_QR" Type="XML_MODEL"/>
		<Step File="DeltaSnapshot.sql" Type="PROC"/>
	</Refresh>
	<Remove>
	</Remove>
</Package>

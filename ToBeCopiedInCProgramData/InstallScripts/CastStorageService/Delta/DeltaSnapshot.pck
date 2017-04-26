<?xml version="1.0" encoding="iso-8859-1" standalone="no"?>
<Package DatabaseKind="KB_CENTRAL" Description="Delta Snapshot" Display="Delta Snapshot" PackName="DELTA_SNAPSHOT" SupportedServer="ALL" Type="SPECIFIC" Version="1.0.0.1000">
	<Include>
	</Include>
	<Exclude>
	</Exclude>
	<Install>
		<Step File="table_delta_snapshot.xml" Option="512" Scope="DELTA_SNAPSHOT" Type="XML_MODEL"/>
	</Install>
	<Update>
	</Update>
	<Refresh>
		<Step File="DeltaSnapshot.sql" Type="PROC"/>
	</Refresh>
	<Remove>
	</Remove>
</Package>

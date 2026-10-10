CREATE TABLE ca_ticket_native_type_binding (
 type_id uuid PRIMARY KEY REFERENCES ca_ticket_type(id),item_id integer NOT NULL UNIQUE CHECK(item_id>0)
);
REVOKE ALL ON ca_ticket_native_type_binding FROM PUBLIC;
ALTER TABLE ca_ticket_order ADD CONSTRAINT ca_ticket_order_event_identity UNIQUE(id,event_id);
ALTER TABLE ca_checkin ADD CONSTRAINT ca_checkin_order_event FOREIGN KEY(order_id,event_id) REFERENCES ca_ticket_order(id,event_id);

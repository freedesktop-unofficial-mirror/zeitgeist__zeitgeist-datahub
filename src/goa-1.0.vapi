[CCode (cprefix = "GoaClient", lower_case_cprefix = "goa_client_", cheader_filename = "goa/goa.h")]
class GoaClient {
    public async GoaClient ();
    public GoaClient.sync ();
    public GLib.List<GoaObject> get_accounts ();
}

[CCode (cprefix = "GoaObject", lower_case_cprefix = "goa_object_", cheader_filename = "goa/goa.h")]
class GoaObject {
}

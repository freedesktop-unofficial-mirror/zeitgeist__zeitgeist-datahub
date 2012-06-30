[CCode (cprefix = "GdGDataGoaAuthorizer", lower_case_cprefix = "gd_gdata_goa_authorizer_", cheader_filename = "gd-gdata-goa-authorizer.h")]
class GoogleAuthorizer {
    public GoogleAuthorizer (GoaObject *goa_object);
    public GoaObject* get_goa_object ();
}

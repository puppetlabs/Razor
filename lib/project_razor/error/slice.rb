# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require_rel "slice/"

module ProjectRazor
  module Error
    module Slice

      [
        [ 'InputError'                , 111 , {'@http_err'=>:bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'InvalidPlugin'             , 112 , {'@http_err'=>:bad_request}           , ''          , 'ProjectRazor::Error::Slice::InputError' ],
        [ 'InvalidTemplate'           , 113 , {'@http_err'=>:bad_request}           , ''          , 'ProjectRazor::Error::Slice::InputError' ],
        [ 'MissingArgument'           , 114 , {'@http_err'=>:bad_request}           , ''          , 'ProjectRazor::Error::Slice::InputError' ],
        [ 'InvalidCommand'            , 115 , {'@http_err'=>:bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'InvalidUUID'               , 116 , {'@http_err'=>:bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'SliceCommandParsingFailed' , 121 , {'@http_err'=>:not_found}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'NotFound'                  , 122 , {'@http_err'=>:not_found}             , 'Not found' , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'CouldNotRegisterNode'      , 123 , {'@http_err'=>:not_found}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'InternalError'             , 131 , {'@http_err'=>:internal_server_error} , ''          , 'ProjectRazor::Error::Slice::Generic' ],
        [ 'NotImplemented'            , 141 , {'@http_err'=>:forbidden}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
      ].each do |err|
        ProjectRazor::Error.create_class *err
      end

    end
  end
end

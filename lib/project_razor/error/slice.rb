# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require_rel "slice/"

module ProjectRazor
  module Error
    module Slice

      [
          [ 'InputError'                , 111 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidPlugin'             , 112 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidTemplate'           , 113 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MissingArgument'           , 114 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidCommand'            , 115 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidUUID'               , 116 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MissingMK'                 , 117 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidPathItem'           , 118 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidImageFilePath'      , 119 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CommandFailed'             , 120 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidImageType'          , 121 , {'@http_err' => :bad_request}           , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'SliceCommandParsingFailed' , 122 , {'@http_err' => :not_found}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'NotFound'                  , 123 , {'@http_err' => :not_found}             , 'Not found' , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CouldNotRegisterNode'      , 124 , {'@http_err' => :not_found}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InternalError'             , 131 , {'@http_err' => :internal_server_error} , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'NotImplemented'            , 141 , {'@http_err' => :forbidden}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CouldNotCreate'            , 125 , {'@http_err'=>:forbidden}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CouldNotUpdate'            , 126 , {'@http_err'=>:forbidden}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CouldNotRemove'            , 127 , {'@http_err'=>:forbidden}             , ''          , 'ProjectRazor::Error::Slice::Generic' ],
      ].each do |err|
        ProjectRazor::Error.create_class *err
      end

    end
  end
end

require_rel "slice/"

module ProjectRazor
  module Error
    class Slice

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
          [ 'CouldNotCreate'            , 125 , {'@http_err'=> :forbidden}              , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CouldNotUpdate'            , 126 , {'@http_err'=> :forbidden}              , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'CouldNotRemove'            , 127 , {'@http_err'=> :forbidden}              , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MethodNotAllowed'          , 128 , {'@http_err'=> :method_not_allowed}     , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidModelTemplate'      , 150 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'UserCancelled'             , 151 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MissingModelMetadata'      , 152 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidModelMetadata'      , 153 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidPolicyTemplate'     , 154 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidModel'              , 155 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MissingTags'               , 156 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'NoCallbackFound'           , 157 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MissingActiveModelUUID'    , 158 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'MissingCallbackNamespace'  , 159 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'ActiveModelInvalid'        , 160 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
          [ 'InvalidMaximumCount'       , 161 , {'@http_err'=> :bad_request}            , ''          , 'ProjectRazor::Error::Slice::Generic' ],
      ].each do |err|
        ProjectRazor::Error.create_class *err
      end

    end
  end
end

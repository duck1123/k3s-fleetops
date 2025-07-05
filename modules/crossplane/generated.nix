# This file was generated with nixidy CRD generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:
with lib; let
  hasAttrNotNull = attr: set: hasAttr attr set && set.${attr} != null;

  attrsToList = values:
    if values != null
    then
      sort (
        a: b:
          if (hasAttrNotNull "_priority" a && hasAttrNotNull "_priority" b)
          then a._priority < b._priority
          else false
      ) (mapAttrsToList (n: v: v) values)
    else values;

  getDefaults = resource: group: version: kind:
    catAttrs "default" (filter (
        default:
          (default.resource == null || default.resource == resource)
          && (default.group == null || default.group == group)
          && (default.version == null || default.version == version)
          && (default.kind == null || default.kind == kind)
      )
      config.defaults);

  types =
    lib.types
    // rec {
      str = mkOptionType {
        name = "str";
        description = "string";
        check = isString;
        merge = mergeEqualOption;
      };

      # Either value of type `finalType` or `coercedType`, the latter is
      # converted to `finalType` using `coerceFunc`.
      coercedTo = coercedType: coerceFunc: finalType:
        mkOptionType rec {
          inherit (finalType) getSubOptions getSubModules;

          name = "coercedTo";
          description = "${finalType.description} or ${coercedType.description}";
          check = x: finalType.check x || coercedType.check x;
          merge = loc: defs: let
            coerceVal = val:
              if finalType.check val
              then val
              else let
                coerced = coerceFunc val;
              in
                assert finalType.check coerced; coerced;
          in
            finalType.merge loc (map (def: def // {value = coerceVal def.value;}) defs);
          substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
          typeMerge = t1: t2: null;
          functor = (defaultFunctor name) // {wrapped = finalType;};
        };
    };

  mkOptionDefault = mkOverride 1001;

  mergeValuesByKey = attrMergeKey: listMergeKeys: values:
    listToAttrs (imap0
      (i: value:
        nameValuePair (
          if hasAttr attrMergeKey value
          then
            if isAttrs value.${attrMergeKey}
            then toString value.${attrMergeKey}.content
            else (toString value.${attrMergeKey})
          else
            # generate merge key for list elements if it's not present
            "__kubenix_list_merge_key_"
            + (concatStringsSep "" (map (
                key:
                  if isAttrs value.${key}
                  then toString value.${key}.content
                  else (toString value.${key})
              )
              listMergeKeys))
        ) (value // {_priority = i;}))
      values);

  submoduleOf = ref:
    types.submodule ({name, ...}: {
      options = definitions."${ref}".options or {};
      config = definitions."${ref}".config or {};
    });

  globalSubmoduleOf = ref:
    types.submodule ({name, ...}: {
      options = config.definitions."${ref}".options or {};
      config = config.definitions."${ref}".config or {};
    });

  submoduleWithMergeOf = ref: mergeKey:
    types.submodule ({name, ...}: let
      convertName = name:
        if definitions."${ref}".options.${mergeKey}.type == types.int
        then toInt name
        else name;
    in {
      options =
        definitions."${ref}".options
        // {
          # position in original array
          _priority = mkOption {
            type = types.nullOr types.int;
            default = null;
          };
        };
      config =
        definitions."${ref}".config
        // {
          ${mergeKey} = mkOverride 1002 (
            # use name as mergeKey only if it is not coming from mergeValuesByKey
            if (!hasPrefix "__kubenix_list_merge_key_" name)
            then convertName name
            else null
          );
        };
    });

  submoduleForDefinition = ref: resource: kind: group: version: let
    apiVersion =
      if group == "core"
      then version
      else "${group}/${version}";
  in
    types.submodule ({name, ...}: {
      inherit (definitions."${ref}") options;

      imports = getDefaults resource group version kind;
      config = mkMerge [
        definitions."${ref}".config
        {
          kind = mkOptionDefault kind;
          apiVersion = mkOptionDefault apiVersion;

          # metdata.name cannot use option default, due deep config
          metadata.name = mkOptionDefault name;
        }
      ];
    });

  coerceAttrsOfSubmodulesToListByKey = ref: attrMergeKey: listMergeKeys: (
    types.coercedTo
    (types.listOf (submoduleOf ref))
    (mergeValuesByKey attrMergeKey listMergeKeys)
    (types.attrsOf (submoduleWithMergeOf ref attrMergeKey))
  );

  definitions = {
    "apiextensions.crossplane.io.v1.CompositeResourceDefinition" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "CompositeResourceDefinitionSpec specifies the desired state of the definition.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpec");
        };
        "status" = mkOption {
          description = "CompositeResourceDefinitionStatus shows the observed state of the definition.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpec" = {
      options = {
        "claimNames" = mkOption {
          description = "ClaimNames specifies the names of an optional composite resource claim.\nWhen claim names are specified Crossplane will create a namespaced\n'composite resource claim' CRD that corresponds to the defined composite\nresource. This composite resource claim acts as a namespaced proxy for\nthe composite resource; creating, updating, or deleting the claim will\ncreate, update, or delete a corresponding composite resource. You may add\nclaim names to an existing CompositeResourceDefinition, but they cannot\nbe changed or removed once they have been set.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecClaimNames");
        };
        "connectionSecretKeys" = mkOption {
          description = "ConnectionSecretKeys is the list of keys that will be exposed to the end\nuser of the defined kind.\nIf the list is empty, all keys will be published.";
          type = types.nullOr (types.listOf types.str);
        };
        "conversion" = mkOption {
          description = "Conversion defines all conversion settings for the defined Composite resource.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversion");
        };
        "defaultCompositeDeletePolicy" = mkOption {
          description = "DefaultCompositeDeletePolicy is the policy used when deleting the Composite\nthat is associated with the Claim if no policy has been specified.";
          type = types.nullOr types.str;
        };
        "defaultCompositionRef" = mkOption {
          description = "DefaultCompositionRef refers to the Composition resource that will be used\nin case no composition selector is given.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecDefaultCompositionRef");
        };
        "defaultCompositionUpdatePolicy" = mkOption {
          description = "DefaultCompositionUpdatePolicy is the policy used when updating composites after a new\nComposition Revision has been created if no policy has been specified on the composite.";
          type = types.nullOr types.str;
        };
        "enforcedCompositionRef" = mkOption {
          description = "EnforcedCompositionRef refers to the Composition resource that will be used\nby all composite instances whose schema is defined by this definition.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecEnforcedCompositionRef");
        };
        "group" = mkOption {
          description = "Group specifies the API group of the defined composite resource.\nComposite resources are served under `/apis/<group>/...`. Must match the\nname of the XRD (in the form `<names.plural>.<group>`).";
          type = types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "names" = mkOption {
          description = "Names specifies the resource and kind names of the defined composite\nresource.";
          type = submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecNames";
        };
        "versions" = mkOption {
          description = "Versions is the list of all API versions of the defined composite\nresource. Version names are used to compute the order in which served\nversions are listed in API discovery. If the version string is\n\"kube-like\", it will sort above non \"kube-like\" version strings, which\nare ordered lexicographically. \"Kube-like\" versions start with a \"v\",\nthen are followed by a number (the major version), then optionally the\nstring \"alpha\" or \"beta\" and another number (the minor version). These\nare sorted first by GA > beta > alpha (where GA is a version with no\nsuffix such as beta or alpha), and then by comparing major version, then\nminor version. An example sorted list of versions: v10, v2, v1, v11beta2,\nv10beta3, v3beta1, v12alpha1, v11alpha2, foo1, foo10.";
          type = coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecVersions" "name" [];
          apply = attrsToList;
        };
      };

      config = {
        "claimNames" = mkOverride 1002 null;
        "connectionSecretKeys" = mkOverride 1002 null;
        "conversion" = mkOverride 1002 null;
        "defaultCompositeDeletePolicy" = mkOverride 1002 null;
        "defaultCompositionRef" = mkOverride 1002 null;
        "defaultCompositionUpdatePolicy" = mkOverride 1002 null;
        "enforcedCompositionRef" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecClaimNames" = {
      options = {
        "categories" = mkOption {
          description = "categories is a list of grouped resources this custom resource belongs to (e.g. 'all').\nThis is published in API discovery documents, and used by clients to support invocations like\n`kubectl get all`.";
          type = types.nullOr (types.listOf types.str);
        };
        "kind" = mkOption {
          description = "kind is the serialized kind of the resource. It is normally CamelCase and singular.\nCustom resource instances will use this value as the `kind` attribute in API calls.";
          type = types.str;
        };
        "listKind" = mkOption {
          description = "listKind is the serialized kind of the list for this resource. Defaults to \"`kind`List\".";
          type = types.nullOr types.str;
        };
        "plural" = mkOption {
          description = "plural is the plural name of the resource to serve.\nThe custom resources are served under `/apis/<group>/<version>/.../<plural>`.\nMust match the name of the CustomResourceDefinition (in the form `<names.plural>.<group>`).\nMust be all lowercase.";
          type = types.str;
        };
        "shortNames" = mkOption {
          description = "shortNames are short names for the resource, exposed in API discovery documents,\nand used by clients to support invocations like `kubectl get <shortname>`.\nIt must be all lowercase.";
          type = types.nullOr (types.listOf types.str);
        };
        "singular" = mkOption {
          description = "singular is the singular name of the resource. It must be all lowercase. Defaults to lowercased `kind`.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "categories" = mkOverride 1002 null;
        "listKind" = mkOverride 1002 null;
        "shortNames" = mkOverride 1002 null;
        "singular" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversion" = {
      options = {
        "strategy" = mkOption {
          description = "strategy specifies how custom resources are converted between versions. Allowed values are:\n- `\"None\"`: The converter only change the apiVersion and would not touch any other field in the custom resource.\n- `\"Webhook\"`: API Server will call to an external webhook to do the conversion. Additional information\n  is needed for this option. This requires spec.preserveUnknownFields to be false, and spec.conversion.webhook to be set.";
          type = types.str;
        };
        "webhook" = mkOption {
          description = "webhook describes how to call the conversion webhook. Required when `strategy` is set to `\"Webhook\"`.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversionWebhook");
        };
      };

      config = {
        "webhook" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversionWebhook" = {
      options = {
        "clientConfig" = mkOption {
          description = "clientConfig is the instructions for how to call the webhook if strategy is `Webhook`.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversionWebhookClientConfig");
        };
        "conversionReviewVersions" = mkOption {
          description = "conversionReviewVersions is an ordered list of preferred `ConversionReview`\nversions the Webhook expects. The API server will use the first version in\nthe list which it supports. If none of the versions specified in this list\nare supported by API server, conversion will fail for the custom resource.\nIf a persisted Webhook configuration specifies allowed versions and does not\ninclude any versions known to the API Server, calls to the webhook will fail.";
          type = types.listOf types.str;
        };
      };

      config = {
        "clientConfig" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversionWebhookClientConfig" = {
      options = {
        "caBundle" = mkOption {
          description = "caBundle is a PEM encoded CA bundle which will be used to validate the webhook's server certificate.\nIf unspecified, system trust roots on the apiserver are used.";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "service is a reference to the service for this webhook. Either\nservice or url must be specified.\n\nIf the webhook is running within the cluster, then you should use `service`.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversionWebhookClientConfigService");
        };
        "url" = mkOption {
          description = "url gives the location of the webhook, in standard URL form\n(`scheme://host:port/path`). Exactly one of `url` or `service`\nmust be specified.\n\nThe `host` should not refer to a service running in the cluster; use\nthe `service` field instead. The host might be resolved via external\nDNS in some apiservers (e.g., `kube-apiserver` cannot resolve\nin-cluster DNS as that would be a layering violation). `host` may\nalso be an IP address.\n\nPlease note that using `localhost` or `127.0.0.1` as a `host` is\nrisky unless you take great care to run this webhook on all hosts\nwhich run an apiserver which might need to make calls to this\nwebhook. Such installs are likely to be non-portable, i.e., not easy\nto turn up in a new cluster.\n\nThe scheme must be \"https\"; the URL must begin with \"https://\".\n\nA path is optional, and if present may be any string permissible in\na URL. You may use the path to pass an arbitrary string to the\nwebhook, for example, a cluster identifier.\n\nAttempting to use a user or basic auth e.g. \"user:password@\" is not\nallowed. Fragments (\"#...\") and query parameters (\"?...\") are not\nallowed, either.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "caBundle" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "url" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecConversionWebhookClientConfigService" = {
      options = {
        "name" = mkOption {
          description = "name is the name of the service.\nRequired";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "namespace is the namespace of the service.\nRequired";
          type = types.str;
        };
        "path" = mkOption {
          description = "path is an optional URL path at which the webhook will be contacted.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "port is an optional service port at which the webhook will be contacted.\n`port` should be a valid port number (1-65535, inclusive).\nDefaults to 443 for backward compatibility.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecDefaultCompositionRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the Composition.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecEnforcedCompositionRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the Composition.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecNames" = {
      options = {
        "categories" = mkOption {
          description = "categories is a list of grouped resources this custom resource belongs to (e.g. 'all').\nThis is published in API discovery documents, and used by clients to support invocations like\n`kubectl get all`.";
          type = types.nullOr (types.listOf types.str);
        };
        "kind" = mkOption {
          description = "kind is the serialized kind of the resource. It is normally CamelCase and singular.\nCustom resource instances will use this value as the `kind` attribute in API calls.";
          type = types.str;
        };
        "listKind" = mkOption {
          description = "listKind is the serialized kind of the list for this resource. Defaults to \"`kind`List\".";
          type = types.nullOr types.str;
        };
        "plural" = mkOption {
          description = "plural is the plural name of the resource to serve.\nThe custom resources are served under `/apis/<group>/<version>/.../<plural>`.\nMust match the name of the CustomResourceDefinition (in the form `<names.plural>.<group>`).\nMust be all lowercase.";
          type = types.str;
        };
        "shortNames" = mkOption {
          description = "shortNames are short names for the resource, exposed in API discovery documents,\nand used by clients to support invocations like `kubectl get <shortname>`.\nIt must be all lowercase.";
          type = types.nullOr (types.listOf types.str);
        };
        "singular" = mkOption {
          description = "singular is the singular name of the resource. It must be all lowercase. Defaults to lowercased `kind`.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "categories" = mkOverride 1002 null;
        "listKind" = mkOverride 1002 null;
        "shortNames" = mkOverride 1002 null;
        "singular" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecVersions" = {
      options = {
        "additionalPrinterColumns" = mkOption {
          description = "AdditionalPrinterColumns specifies additional columns returned in Table\noutput. If no columns are specified, a single column displaying the age\nof the custom resource is used. See the following link for details:\nhttps://kubernetes.io/docs/reference/using-api/api-concepts/#receiving-resources-as-tables";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecVersionsAdditionalPrinterColumns" "name" []);
          apply = attrsToList;
        };
        "deprecated" = mkOption {
          description = "The deprecated field specifies that this version is deprecated and should\nnot be used.";
          type = types.nullOr types.bool;
        };
        "deprecationWarning" = mkOption {
          description = "DeprecationWarning specifies the message that should be shown to the user\nwhen using this version.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of this version, e.g. u201cv1u201d, u201cv2beta1u201d, etc. Composite resources are\nserved under this version at `/apis/<group>/<version>/...` if `served` is\ntrue.";
          type = types.str;
        };
        "referenceable" = mkOption {
          description = "Referenceable specifies that this version may be referenced by a\nComposition in order to configure which resources an XR may be composed\nof. Exactly one version must be marked as referenceable; all Compositions\nmust target only the referenceable version. The referenceable version\nmust be served. It's mapped to the CRD's `spec.versions[*].storage` field.";
          type = types.bool;
        };
        "schema" = mkOption {
          description = "Schema describes the schema used for validation, pruning, and defaulting\nof this version of the defined composite resource. Fields required by all\ncomposite resources will be injected into this schema automatically, and\nwill override equivalently named fields in this schema. Omitting this\nschema results in a schema that contains only the fields required by all\ncomposite resources.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecVersionsSchema");
        };
        "served" = mkOption {
          description = "Served specifies that this version should be served via REST APIs.";
          type = types.bool;
        };
      };

      config = {
        "additionalPrinterColumns" = mkOverride 1002 null;
        "deprecated" = mkOverride 1002 null;
        "deprecationWarning" = mkOverride 1002 null;
        "schema" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecVersionsAdditionalPrinterColumns" = {
      options = {
        "description" = mkOption {
          description = "description is a human readable description of this column.";
          type = types.nullOr types.str;
        };
        "format" = mkOption {
          description = "format is an optional OpenAPI type definition for this column. The 'name' format is applied\nto the primary identifier column to assist in clients identifying column is the resource name.\nSee https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#data-types for details.";
          type = types.nullOr types.str;
        };
        "jsonPath" = mkOption {
          description = "jsonPath is a simple JSON path (i.e. with array notation) which is evaluated against\neach custom resource to produce the value for this column.";
          type = types.str;
        };
        "name" = mkOption {
          description = "name is a human readable name for the column.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "priority is an integer defining the relative importance of this column compared to others. Lower\nnumbers are considered higher priority. Columns that may be omitted in limited space scenarios\nshould be given a priority greater than 0.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "type is an OpenAPI type definition for this column.\nSee https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#data-types for details.";
          type = types.str;
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "format" = mkOverride 1002 null;
        "priority" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionSpecVersionsSchema" = {
      options = {
        "openAPIV3Schema" = mkOption {
          description = "OpenAPIV3Schema is the OpenAPI v3 schema to use for validation and\npruning.";
          type = types.nullOr types.attrs;
        };
      };

      config = {
        "openAPIV3Schema" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusConditions"));
        };
        "controllers" = mkOption {
          description = "Controllers represents the status of the controllers that power this\ncomposite resource definition.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusControllers");
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "controllers" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusControllers" = {
      options = {
        "compositeResourceClaimType" = mkOption {
          description = "The CompositeResourceClaimTypeRef is the type of composite resource claim\nthat Crossplane is currently reconciling for this definition. Its version\nwill eventually become consistent with the definition's referenceable\nversion. Note that clients may interact with any served type; this is\nsimply the type that Crossplane interacts with.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusControllersCompositeResourceClaimType");
        };
        "compositeResourceType" = mkOption {
          description = "The CompositeResourceTypeRef is the type of composite resource that\nCrossplane is currently reconciling for this definition. Its version will\neventually become consistent with the definition's referenceable version.\nNote that clients may interact with any served type; this is simply the\ntype that Crossplane interacts with.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusControllersCompositeResourceType");
        };
      };

      config = {
        "compositeResourceClaimType" = mkOverride 1002 null;
        "compositeResourceType" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusControllersCompositeResourceClaimType" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the type.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the type.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositeResourceDefinitionStatusControllersCompositeResourceType" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the type.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the type.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.Composition" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "CompositionSpec specifies desired state of a composition.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevision" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "CompositionRevisionSpec specifies the desired state of the composition\nrevision.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpec");
        };
        "status" = mkOption {
          description = "CompositionRevisionStatus shows the observed state of the composition\nrevision.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpec" = {
      options = {
        "compositeTypeRef" = mkOption {
          description = "CompositeTypeRef specifies the type of composite resource that this\ncomposition is compatible with.";
          type = submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecCompositeTypeRef";
        };
        "mode" = mkOption {
          description = "Mode controls what type or \"mode\" of Composition will be used.\n\n\"Pipeline\" indicates that a Composition specifies a pipeline of\nComposition Functions, each of which is responsible for producing\ncomposed resources that Crossplane should create or update.\n\n\"Resources\" indicates that a Composition uses what is commonly referred\nto as \"Patch & Transform\" or P&T composition. This mode of Composition\nuses an array of resources, each a template for a composed resource.\n\nAll Compositions should use Pipeline mode. Resources mode is deprecated.\nResources mode won't be removed in Crossplane 1.x, and will remain the\ndefault to avoid breaking legacy Compositions. However, it's no longer\naccepting new features, and only accepting security related bug fixes.";
          type = types.nullOr types.str;
        };
        "patchSets" = mkOption {
          description = "PatchSets define a named set of patches that may be included by any\nresource in this Composition. PatchSets cannot themselves refer to other\nPatchSets.\n\nPatchSets are only used by the \"Resources\" mode of Composition. They\nare ignored by other modes.\n\nDeprecated: Use Composition Functions instead.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSets" "name" []);
          apply = attrsToList;
        };
        "pipeline" = mkOption {
          description = "Pipeline is a list of composition function steps that will be used when a\ncomposite resource referring to this composition is created. One of\nresources and pipeline must be specified - you cannot specify both.\n\nThe Pipeline is only used by the \"Pipeline\" mode of Composition. It is\nignored by other modes.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipeline"));
        };
        "publishConnectionDetailsWithStoreConfigRef" = mkOption {
          description = "PublishConnectionDetailsWithStoreConfig specifies the secret store config\nwith which the connection details of composite resources dynamically\nprovisioned using this composition will be published.\n\nTHIS IS AN ALPHA FIELD. Do not use it in production. It is not honored\nunless the relevant Crossplane feature flag is enabled, and may be\nchanged or removed without notice.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPublishConnectionDetailsWithStoreConfigRef");
        };
        "resources" = mkOption {
          description = "Resources is a list of resource templates that will be used when a\ncomposite resource referring to this composition is created.\n\nResources are only used by the \"Resources\" mode of Composition. They are\nignored by other modes.\n\nDeprecated: Use Composition Functions instead.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionRevisionSpecResources" "name" []);
          apply = attrsToList;
        };
        "revision" = mkOption {
          description = "Revision number. Newer revisions have larger numbers.\n\nThis number can change. When a Composition transitions from state A\n-> B -> A there will be only two CompositionRevisions. Crossplane will\nedit the original CompositionRevision to change its revision number from\n0 to 2.";
          type = types.int;
        };
        "writeConnectionSecretsToNamespace" = mkOption {
          description = "WriteConnectionSecretsToNamespace specifies the namespace in which the\nconnection secrets of composite resource dynamically provisioned using\nthis composition will be created.\nThis field is planned to be replaced in a future release in favor of\nPublishConnectionDetailsWithStoreConfigRef. Currently, both could be\nset independently and connection details would be published to both\nwithout affecting each other as long as related fields at MR level\nspecified.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
        "patchSets" = mkOverride 1002 null;
        "pipeline" = mkOverride 1002 null;
        "publishConnectionDetailsWithStoreConfigRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "writeConnectionSecretsToNamespace" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecCompositeTypeRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the type.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the type.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSets" = {
      options = {
        "name" = mkOption {
          description = "Name of this PatchSet.";
          type = types.str;
        };
        "patches" = mkOption {
          description = "Patches will be applied as an overlay to the base resource.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatches");
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatches" = {
      options = {
        "combine" = mkOption {
          description = "Combine is the patch configuration for a CombineFromComposite or\nCombineToComposite patch.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesCombine");
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the resource whose value is\nto be used as input. Required when type is FromCompositeFieldPath or\nToCompositeFieldPath.";
          type = types.nullOr types.str;
        };
        "patchSetName" = mkOption {
          description = "PatchSetName to include patches from. Required when type is PatchSet.";
          type = types.nullOr types.str;
        };
        "policy" = mkOption {
          description = "Policy configures the specifics of patching behaviour.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesPolicy");
        };
        "toFieldPath" = mkOption {
          description = "ToFieldPath is the path of the field on the resource whose value will\nbe changed with the result of transforms. Leave empty if you'd like to\npropagate to the same path as fromFieldPath.";
          type = types.nullOr types.str;
        };
        "transforms" = mkOption {
          description = "Transforms are the list of functions that are used as a FIFO pipe for the\ninput to be transformed.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransforms"));
        };
        "type" = mkOption {
          description = "Type sets the patching behaviour to be used. Each patch type may require\nits own fields to be set on the Patch object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "combine" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "patchSetName" = mkOverride 1002 null;
        "policy" = mkOverride 1002 null;
        "toFieldPath" = mkOverride 1002 null;
        "transforms" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesCombine" = {
      options = {
        "strategy" = mkOption {
          description = "Strategy defines the strategy to use to combine the input variable values.\nCurrently only string is supported.";
          type = types.str;
        };
        "string" = mkOption {
          description = "String declares that input variables should be combined into a single\nstring, using the relevant settings for formatting purposes.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesCombineString");
        };
        "variables" = mkOption {
          description = "Variables are the list of variables whose values will be retrieved and\ncombined.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesCombineVariables");
        };
      };

      config = {
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesCombineString" = {
      options = {
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesCombineVariables" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the source whose value is\nto be used as input.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesPolicy" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath specifies how to patch from a field path. The default is\n'Optional', which means the patch will be a no-op if the specified\nfromFieldPath does not exist. Use 'Required' if the patch should fail if\nthe specified path does not exist.";
          type = types.nullOr types.str;
        };
        "mergeOptions" = mkOption {
          description = "MergeOptions Specifies merge options on a field path.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesPolicyMergeOptions");
        };
      };

      config = {
        "fromFieldPath" = mkOverride 1002 null;
        "mergeOptions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesPolicyMergeOptions" = {
      options = {
        "appendSlice" = mkOption {
          description = "Specifies that already existing elements in a merged slice should be preserved";
          type = types.nullOr types.bool;
        };
        "keepMapValues" = mkOption {
          description = "Specifies that already existing values in a merged map should be preserved";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "appendSlice" = mkOverride 1002 null;
        "keepMapValues" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransforms" = {
      options = {
        "convert" = mkOption {
          description = "Convert is used to cast the input into the given output type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsConvert");
        };
        "map" = mkOption {
          description = "Map uses the input as a key in the given map and returns the value.";
          type = types.nullOr types.attrs;
        };
        "match" = mkOption {
          description = "Match is a more complex version of Map that matches a list of patterns.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsMatch");
        };
        "math" = mkOption {
          description = "Math is used to transform the input via mathematical operations such as\nmultiplication.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsMath");
        };
        "string" = mkOption {
          description = "String is used to transform the input into a string or a different kind\nof string. Note that the input does not necessarily need to be a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsString");
        };
        "type" = mkOption {
          description = "Type of the transform to be run.";
          type = types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "map" = mkOverride 1002 null;
        "match" = mkOverride 1002 null;
        "math" = mkOverride 1002 null;
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsConvert" = {
      options = {
        "format" = mkOption {
          description = "The expected input format.\n\n* `quantity` - parses the input as a K8s [`resource.Quantity`](https://pkg.go.dev/k8s.io/apimachinery/pkg/api/resource#Quantity).\nOnly used during `string -> float64` conversions.\n* `json` - parses the input as a JSON string.\nOnly used during `string -> object` or `string -> list` conversions.\n\nIf this property is null, the default conversion is applied.";
          type = types.nullOr types.str;
        };
        "toType" = mkOption {
          description = "ToType is the type of the output of this transform.";
          type = types.str;
        };
      };

      config = {
        "format" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsMatch" = {
      options = {
        "fallbackTo" = mkOption {
          description = "Determines to what value the transform should fallback if no pattern matches.";
          type = types.nullOr types.str;
        };
        "fallbackValue" = mkOption {
          description = "The fallback value that should be returned by the transform if now pattern\nmatches.";
          type = types.nullOr types.attrs;
        };
        "patterns" = mkOption {
          description = "The patterns that should be tested against the input string.\nPatterns are tested in order. The value of the first match is used as\nresult of this transform.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsMatchPatterns"));
        };
      };

      config = {
        "fallbackTo" = mkOverride 1002 null;
        "fallbackValue" = mkOverride 1002 null;
        "patterns" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsMatchPatterns" = {
      options = {
        "literal" = mkOption {
          description = "Literal exactly matches the input string (case sensitive).\nIs required if `type` is `literal`.";
          type = types.nullOr types.str;
        };
        "regexp" = mkOption {
          description = "Regexp to match against the input string.\nIs required if `type` is `regexp`.";
          type = types.nullOr types.str;
        };
        "result" = mkOption {
          description = "The value that is used as result of the transform if the pattern matches.";
          type = types.attrs;
        };
        "type" = mkOption {
          description = "Type specifies how the pattern matches the input.\n\n* `literal` - the pattern value has to exactly match (case sensitive) the\ninput string. This is the default.\n\n* `regexp` - the pattern treated as a regular expression against\nwhich the input string is tested. Crossplane will throw an error if the\nkey is not a valid regexp.";
          type = types.str;
        };
      };

      config = {
        "literal" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsMath" = {
      options = {
        "clampMax" = mkOption {
          description = "ClampMax makes sure that the value is not bigger than the given value.";
          type = types.nullOr types.int;
        };
        "clampMin" = mkOption {
          description = "ClampMin makes sure that the value is not smaller than the given value.";
          type = types.nullOr types.int;
        };
        "multiply" = mkOption {
          description = "Multiply the value.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "Type of the math transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clampMax" = mkOverride 1002 null;
        "clampMin" = mkOverride 1002 null;
        "multiply" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsString" = {
      options = {
        "convert" = mkOption {
          description = "Optional conversion method to be specified.\n`ToUpper` and `ToLower` change the letter case of the input string.\n`ToBase64` and `FromBase64` perform a base64 conversion based on the input string.\n`ToJson` converts any input value into its raw JSON representation.\n`ToSha1`, `ToSha256` and `ToSha512` generate a hash value based on the input\nconverted to JSON.\n`ToAdler32` generate a addler32 hash based on the input string.";
          type = types.nullOr types.str;
        };
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.nullOr types.str;
        };
        "join" = mkOption {
          description = "Join defines parameters to join a slice of values to a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsStringJoin");
        };
        "regexp" = mkOption {
          description = "Extract a match from the input using a regular expression.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsStringRegexp");
        };
        "trim" = mkOption {
          description = "Trim the prefix or suffix from the input";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type of the string transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "fmt" = mkOverride 1002 null;
        "join" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
        "trim" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsStringJoin" = {
      options = {
        "separator" = mkOption {
          description = "Separator defines the character that should separate the values from each\nother in the joined string.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPatchSetsPatchesTransformsStringRegexp" = {
      options = {
        "group" = mkOption {
          description = "Group number to match. 0 (the default) matches the entire expression.";
          type = types.nullOr types.int;
        };
        "match" = mkOption {
          description = "Match string. May optionally include submatches, aka capture groups.\nSee https://pkg.go.dev/regexp/ for details.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipeline" = {
      options = {
        "credentials" = mkOption {
          description = "Credentials are optional credentials that the Composition Function needs.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipelineCredentials" "name" ["name"]);
          apply = attrsToList;
        };
        "functionRef" = mkOption {
          description = "FunctionRef is a reference to the Composition Function this step should\nexecute.";
          type = submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipelineFunctionRef";
        };
        "input" = mkOption {
          description = "Input is an optional, arbitrary Kubernetes resource (i.e. a resource\nwith an apiVersion and kind) that will be passed to the Composition\nFunction as the 'input' of its RunFunctionRequest.";
          type = types.nullOr types.attrs;
        };
        "step" = mkOption {
          description = "Step name. Must be unique within its Pipeline.";
          type = types.str;
        };
      };

      config = {
        "credentials" = mkOverride 1002 null;
        "input" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipelineCredentials" = {
      options = {
        "name" = mkOption {
          description = "Name of this set of credentials.";
          type = types.str;
        };
        "secretRef" = mkOption {
          description = "A SecretRef is a reference to a secret containing credentials that should\nbe supplied to the function.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipelineCredentialsSecretRef");
        };
        "source" = mkOption {
          description = "Source of the function credentials.";
          type = types.str;
        };
      };

      config = {
        "secretRef" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipelineCredentialsSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace of the secret.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPipelineFunctionRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referenced Function.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecPublishConnectionDetailsWithStoreConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referenced StoreConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResources" = {
      options = {
        "base" = mkOption {
          description = "Base is the target resource that the patches will be applied on.";
          type = types.attrs;
        };
        "connectionDetails" = mkOption {
          description = "ConnectionDetails lists the propagation secret keys from this target\nresource to the composition instance connection secret.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesConnectionDetails" "name" []);
          apply = attrsToList;
        };
        "name" = mkOption {
          description = "A Name uniquely identifies this entry within its Composition's resources\narray. Names are optional but *strongly* recommended. When all entries in\nthe resources array are named entries may added, deleted, and reordered\nas long as their names do not change. When entries are not named the\nlength and order of the resources array should be treated as immutable.\nEither all or no entries must be named.";
          type = types.nullOr types.str;
        };
        "patches" = mkOption {
          description = "Patches will be applied as overlay to the base resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatches"));
        };
        "readinessChecks" = mkOption {
          description = "ReadinessChecks allows users to define custom readiness checks. All checks\nhave to return true in order for resource to be considered ready. The\ndefault readiness check is to have the \"Ready\" condition to be \"True\".";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesReadinessChecks"));
        };
      };

      config = {
        "connectionDetails" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "patches" = mkOverride 1002 null;
        "readinessChecks" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesConnectionDetails" = {
      options = {
        "fromConnectionSecretKey" = mkOption {
          description = "FromConnectionSecretKey is the key that will be used to fetch the value\nfrom the composed resource's connection secret.";
          type = types.nullOr types.str;
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the composed resource whose\nvalue to be used as input. Name must be specified if the type is\nFromFieldPath.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the connection secret key that will be propagated to the\nconnection secret of the composition instance. Leave empty if you'd like\nto use the same key name.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type sets the connection detail fetching behaviour to be used. Each\nconnection detail type may require its own fields to be set on the\nConnectionDetail object. If the type is omitted Crossplane will attempt\nto infer it based on which other fields were specified. If multiple\nfields are specified the order of precedence is:\n1. FromValue\n2. FromConnectionSecretKey\n3. FromFieldPath";
          type = types.nullOr types.str;
        };
        "value" = mkOption {
          description = "Value that will be propagated to the connection secret of the composite\nresource. May be set to inject a fixed, non-sensitive connection secret\nvalue, for example a well-known port.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fromConnectionSecretKey" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatches" = {
      options = {
        "combine" = mkOption {
          description = "Combine is the patch configuration for a CombineFromComposite or\nCombineToComposite patch.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesCombine");
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the resource whose value is\nto be used as input. Required when type is FromCompositeFieldPath or\nToCompositeFieldPath.";
          type = types.nullOr types.str;
        };
        "patchSetName" = mkOption {
          description = "PatchSetName to include patches from. Required when type is PatchSet.";
          type = types.nullOr types.str;
        };
        "policy" = mkOption {
          description = "Policy configures the specifics of patching behaviour.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesPolicy");
        };
        "toFieldPath" = mkOption {
          description = "ToFieldPath is the path of the field on the resource whose value will\nbe changed with the result of transforms. Leave empty if you'd like to\npropagate to the same path as fromFieldPath.";
          type = types.nullOr types.str;
        };
        "transforms" = mkOption {
          description = "Transforms are the list of functions that are used as a FIFO pipe for the\ninput to be transformed.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransforms"));
        };
        "type" = mkOption {
          description = "Type sets the patching behaviour to be used. Each patch type may require\nits own fields to be set on the Patch object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "combine" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "patchSetName" = mkOverride 1002 null;
        "policy" = mkOverride 1002 null;
        "toFieldPath" = mkOverride 1002 null;
        "transforms" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesCombine" = {
      options = {
        "strategy" = mkOption {
          description = "Strategy defines the strategy to use to combine the input variable values.\nCurrently only string is supported.";
          type = types.str;
        };
        "string" = mkOption {
          description = "String declares that input variables should be combined into a single\nstring, using the relevant settings for formatting purposes.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesCombineString");
        };
        "variables" = mkOption {
          description = "Variables are the list of variables whose values will be retrieved and\ncombined.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesCombineVariables");
        };
      };

      config = {
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesCombineString" = {
      options = {
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesCombineVariables" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the source whose value is\nto be used as input.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesPolicy" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath specifies how to patch from a field path. The default is\n'Optional', which means the patch will be a no-op if the specified\nfromFieldPath does not exist. Use 'Required' if the patch should fail if\nthe specified path does not exist.";
          type = types.nullOr types.str;
        };
        "mergeOptions" = mkOption {
          description = "MergeOptions Specifies merge options on a field path.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesPolicyMergeOptions");
        };
      };

      config = {
        "fromFieldPath" = mkOverride 1002 null;
        "mergeOptions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesPolicyMergeOptions" = {
      options = {
        "appendSlice" = mkOption {
          description = "Specifies that already existing elements in a merged slice should be preserved";
          type = types.nullOr types.bool;
        };
        "keepMapValues" = mkOption {
          description = "Specifies that already existing values in a merged map should be preserved";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "appendSlice" = mkOverride 1002 null;
        "keepMapValues" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransforms" = {
      options = {
        "convert" = mkOption {
          description = "Convert is used to cast the input into the given output type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsConvert");
        };
        "map" = mkOption {
          description = "Map uses the input as a key in the given map and returns the value.";
          type = types.nullOr types.attrs;
        };
        "match" = mkOption {
          description = "Match is a more complex version of Map that matches a list of patterns.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsMatch");
        };
        "math" = mkOption {
          description = "Math is used to transform the input via mathematical operations such as\nmultiplication.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsMath");
        };
        "string" = mkOption {
          description = "String is used to transform the input into a string or a different kind\nof string. Note that the input does not necessarily need to be a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsString");
        };
        "type" = mkOption {
          description = "Type of the transform to be run.";
          type = types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "map" = mkOverride 1002 null;
        "match" = mkOverride 1002 null;
        "math" = mkOverride 1002 null;
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsConvert" = {
      options = {
        "format" = mkOption {
          description = "The expected input format.\n\n* `quantity` - parses the input as a K8s [`resource.Quantity`](https://pkg.go.dev/k8s.io/apimachinery/pkg/api/resource#Quantity).\nOnly used during `string -> float64` conversions.\n* `json` - parses the input as a JSON string.\nOnly used during `string -> object` or `string -> list` conversions.\n\nIf this property is null, the default conversion is applied.";
          type = types.nullOr types.str;
        };
        "toType" = mkOption {
          description = "ToType is the type of the output of this transform.";
          type = types.str;
        };
      };

      config = {
        "format" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsMatch" = {
      options = {
        "fallbackTo" = mkOption {
          description = "Determines to what value the transform should fallback if no pattern matches.";
          type = types.nullOr types.str;
        };
        "fallbackValue" = mkOption {
          description = "The fallback value that should be returned by the transform if now pattern\nmatches.";
          type = types.nullOr types.attrs;
        };
        "patterns" = mkOption {
          description = "The patterns that should be tested against the input string.\nPatterns are tested in order. The value of the first match is used as\nresult of this transform.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsMatchPatterns"));
        };
      };

      config = {
        "fallbackTo" = mkOverride 1002 null;
        "fallbackValue" = mkOverride 1002 null;
        "patterns" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsMatchPatterns" = {
      options = {
        "literal" = mkOption {
          description = "Literal exactly matches the input string (case sensitive).\nIs required if `type` is `literal`.";
          type = types.nullOr types.str;
        };
        "regexp" = mkOption {
          description = "Regexp to match against the input string.\nIs required if `type` is `regexp`.";
          type = types.nullOr types.str;
        };
        "result" = mkOption {
          description = "The value that is used as result of the transform if the pattern matches.";
          type = types.attrs;
        };
        "type" = mkOption {
          description = "Type specifies how the pattern matches the input.\n\n* `literal` - the pattern value has to exactly match (case sensitive) the\ninput string. This is the default.\n\n* `regexp` - the pattern treated as a regular expression against\nwhich the input string is tested. Crossplane will throw an error if the\nkey is not a valid regexp.";
          type = types.str;
        };
      };

      config = {
        "literal" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsMath" = {
      options = {
        "clampMax" = mkOption {
          description = "ClampMax makes sure that the value is not bigger than the given value.";
          type = types.nullOr types.int;
        };
        "clampMin" = mkOption {
          description = "ClampMin makes sure that the value is not smaller than the given value.";
          type = types.nullOr types.int;
        };
        "multiply" = mkOption {
          description = "Multiply the value.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "Type of the math transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clampMax" = mkOverride 1002 null;
        "clampMin" = mkOverride 1002 null;
        "multiply" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsString" = {
      options = {
        "convert" = mkOption {
          description = "Optional conversion method to be specified.\n`ToUpper` and `ToLower` change the letter case of the input string.\n`ToBase64` and `FromBase64` perform a base64 conversion based on the input string.\n`ToJson` converts any input value into its raw JSON representation.\n`ToSha1`, `ToSha256` and `ToSha512` generate a hash value based on the input\nconverted to JSON.\n`ToAdler32` generate a addler32 hash based on the input string.";
          type = types.nullOr types.str;
        };
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.nullOr types.str;
        };
        "join" = mkOption {
          description = "Join defines parameters to join a slice of values to a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsStringJoin");
        };
        "regexp" = mkOption {
          description = "Extract a match from the input using a regular expression.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsStringRegexp");
        };
        "trim" = mkOption {
          description = "Trim the prefix or suffix from the input";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type of the string transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "fmt" = mkOverride 1002 null;
        "join" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
        "trim" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsStringJoin" = {
      options = {
        "separator" = mkOption {
          description = "Separator defines the character that should separate the values from each\nother in the joined string.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesPatchesTransformsStringRegexp" = {
      options = {
        "group" = mkOption {
          description = "Group number to match. 0 (the default) matches the entire expression.";
          type = types.nullOr types.int;
        };
        "match" = mkOption {
          description = "Match string. May optionally include submatches, aka capture groups.\nSee https://pkg.go.dev/regexp/ for details.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesReadinessChecks" = {
      options = {
        "fieldPath" = mkOption {
          description = "FieldPath shows the path of the field whose value will be used.";
          type = types.nullOr types.str;
        };
        "matchCondition" = mkOption {
          description = "MatchCondition specifies the condition you'd like to match if you're using \"MatchCondition\" type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesReadinessChecksMatchCondition");
        };
        "matchInteger" = mkOption {
          description = "MatchInt is the value you'd like to match if you're using \"MatchInt\" type.";
          type = types.nullOr types.int;
        };
        "matchString" = mkOption {
          description = "MatchString is the value you'd like to match if you're using \"MatchString\" type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type indicates the type of probe you'd like to use.";
          type = types.str;
        };
      };

      config = {
        "fieldPath" = mkOverride 1002 null;
        "matchCondition" = mkOverride 1002 null;
        "matchInteger" = mkOverride 1002 null;
        "matchString" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionSpecResourcesReadinessChecksMatchCondition" = {
      options = {
        "status" = mkOption {
          description = "Status is the status of the condition you'd like to match.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type indicates the type of condition you'd like to use.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionRevisionStatusConditions"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionRevisionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpec" = {
      options = {
        "compositeTypeRef" = mkOption {
          description = "CompositeTypeRef specifies the type of composite resource that this\ncomposition is compatible with.";
          type = submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecCompositeTypeRef";
        };
        "mode" = mkOption {
          description = "Mode controls what type or \"mode\" of Composition will be used.\n\n\"Pipeline\" indicates that a Composition specifies a pipeline of\nComposition Functions, each of which is responsible for producing\ncomposed resources that Crossplane should create or update.\n\n\"Resources\" indicates that a Composition uses what is commonly referred\nto as \"Patch & Transform\" or P&T composition. This mode of Composition\nuses an array of resources, each a template for a composed resource.\n\nAll Compositions should use Pipeline mode. Resources mode is deprecated.\nResources mode won't be removed in Crossplane 1.x, and will remain the\ndefault to avoid breaking legacy Compositions. However, it's no longer\naccepting new features, and only accepting security related bug fixes.";
          type = types.nullOr types.str;
        };
        "patchSets" = mkOption {
          description = "PatchSets define a named set of patches that may be included by any\nresource in this Composition. PatchSets cannot themselves refer to other\nPatchSets.\n\nPatchSets are only used by the \"Resources\" mode of Composition. They\nare ignored by other modes.\n\nDeprecated: Use Composition Functions instead.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionSpecPatchSets" "name" []);
          apply = attrsToList;
        };
        "pipeline" = mkOption {
          description = "Pipeline is a list of composition function steps that will be used when a\ncomposite resource referring to this composition is created. One of\nresources and pipeline must be specified - you cannot specify both.\n\nThe Pipeline is only used by the \"Pipeline\" mode of Composition. It is\nignored by other modes.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPipeline"));
        };
        "publishConnectionDetailsWithStoreConfigRef" = mkOption {
          description = "PublishConnectionDetailsWithStoreConfig specifies the secret store config\nwith which the connection details of composite resources dynamically\nprovisioned using this composition will be published.\n\nTHIS IS AN ALPHA FIELD. Do not use it in production. It is not honored\nunless the relevant Crossplane feature flag is enabled, and may be\nchanged or removed without notice.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPublishConnectionDetailsWithStoreConfigRef");
        };
        "resources" = mkOption {
          description = "Resources is a list of resource templates that will be used when a\ncomposite resource referring to this composition is created.\n\nResources are only used by the \"Resources\" mode of Composition. They are\nignored by other modes.\n\nDeprecated: Use Composition Functions instead.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionSpecResources" "name" []);
          apply = attrsToList;
        };
        "writeConnectionSecretsToNamespace" = mkOption {
          description = "WriteConnectionSecretsToNamespace specifies the namespace in which the\nconnection secrets of composite resource dynamically provisioned using\nthis composition will be created.\nThis field is planned to be replaced in a future release in favor of\nPublishConnectionDetailsWithStoreConfigRef. Currently, both could be\nset independently and connection details would be published to both\nwithout affecting each other as long as related fields at MR level\nspecified.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
        "patchSets" = mkOverride 1002 null;
        "pipeline" = mkOverride 1002 null;
        "publishConnectionDetailsWithStoreConfigRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "writeConnectionSecretsToNamespace" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecCompositeTypeRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the type.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the type.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSets" = {
      options = {
        "name" = mkOption {
          description = "Name of this PatchSet.";
          type = types.str;
        };
        "patches" = mkOption {
          description = "Patches will be applied as an overlay to the base resource.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatches");
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatches" = {
      options = {
        "combine" = mkOption {
          description = "Combine is the patch configuration for a CombineFromComposite or\nCombineToComposite patch.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesCombine");
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the resource whose value is\nto be used as input. Required when type is FromCompositeFieldPath or\nToCompositeFieldPath.";
          type = types.nullOr types.str;
        };
        "patchSetName" = mkOption {
          description = "PatchSetName to include patches from. Required when type is PatchSet.";
          type = types.nullOr types.str;
        };
        "policy" = mkOption {
          description = "Policy configures the specifics of patching behaviour.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesPolicy");
        };
        "toFieldPath" = mkOption {
          description = "ToFieldPath is the path of the field on the resource whose value will\nbe changed with the result of transforms. Leave empty if you'd like to\npropagate to the same path as fromFieldPath.";
          type = types.nullOr types.str;
        };
        "transforms" = mkOption {
          description = "Transforms are the list of functions that are used as a FIFO pipe for the\ninput to be transformed.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransforms"));
        };
        "type" = mkOption {
          description = "Type sets the patching behaviour to be used. Each patch type may require\nits own fields to be set on the Patch object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "combine" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "patchSetName" = mkOverride 1002 null;
        "policy" = mkOverride 1002 null;
        "toFieldPath" = mkOverride 1002 null;
        "transforms" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesCombine" = {
      options = {
        "strategy" = mkOption {
          description = "Strategy defines the strategy to use to combine the input variable values.\nCurrently only string is supported.";
          type = types.str;
        };
        "string" = mkOption {
          description = "String declares that input variables should be combined into a single\nstring, using the relevant settings for formatting purposes.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesCombineString");
        };
        "variables" = mkOption {
          description = "Variables are the list of variables whose values will be retrieved and\ncombined.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesCombineVariables");
        };
      };

      config = {
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesCombineString" = {
      options = {
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesCombineVariables" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the source whose value is\nto be used as input.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesPolicy" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath specifies how to patch from a field path. The default is\n'Optional', which means the patch will be a no-op if the specified\nfromFieldPath does not exist. Use 'Required' if the patch should fail if\nthe specified path does not exist.";
          type = types.nullOr types.str;
        };
        "mergeOptions" = mkOption {
          description = "MergeOptions Specifies merge options on a field path.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesPolicyMergeOptions");
        };
      };

      config = {
        "fromFieldPath" = mkOverride 1002 null;
        "mergeOptions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesPolicyMergeOptions" = {
      options = {
        "appendSlice" = mkOption {
          description = "Specifies that already existing elements in a merged slice should be preserved";
          type = types.nullOr types.bool;
        };
        "keepMapValues" = mkOption {
          description = "Specifies that already existing values in a merged map should be preserved";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "appendSlice" = mkOverride 1002 null;
        "keepMapValues" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransforms" = {
      options = {
        "convert" = mkOption {
          description = "Convert is used to cast the input into the given output type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsConvert");
        };
        "map" = mkOption {
          description = "Map uses the input as a key in the given map and returns the value.";
          type = types.nullOr types.attrs;
        };
        "match" = mkOption {
          description = "Match is a more complex version of Map that matches a list of patterns.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsMatch");
        };
        "math" = mkOption {
          description = "Math is used to transform the input via mathematical operations such as\nmultiplication.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsMath");
        };
        "string" = mkOption {
          description = "String is used to transform the input into a string or a different kind\nof string. Note that the input does not necessarily need to be a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsString");
        };
        "type" = mkOption {
          description = "Type of the transform to be run.";
          type = types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "map" = mkOverride 1002 null;
        "match" = mkOverride 1002 null;
        "math" = mkOverride 1002 null;
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsConvert" = {
      options = {
        "format" = mkOption {
          description = "The expected input format.\n\n* `quantity` - parses the input as a K8s [`resource.Quantity`](https://pkg.go.dev/k8s.io/apimachinery/pkg/api/resource#Quantity).\nOnly used during `string -> float64` conversions.\n* `json` - parses the input as a JSON string.\nOnly used during `string -> object` or `string -> list` conversions.\n\nIf this property is null, the default conversion is applied.";
          type = types.nullOr types.str;
        };
        "toType" = mkOption {
          description = "ToType is the type of the output of this transform.";
          type = types.str;
        };
      };

      config = {
        "format" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsMatch" = {
      options = {
        "fallbackTo" = mkOption {
          description = "Determines to what value the transform should fallback if no pattern matches.";
          type = types.nullOr types.str;
        };
        "fallbackValue" = mkOption {
          description = "The fallback value that should be returned by the transform if now pattern\nmatches.";
          type = types.nullOr types.attrs;
        };
        "patterns" = mkOption {
          description = "The patterns that should be tested against the input string.\nPatterns are tested in order. The value of the first match is used as\nresult of this transform.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsMatchPatterns"));
        };
      };

      config = {
        "fallbackTo" = mkOverride 1002 null;
        "fallbackValue" = mkOverride 1002 null;
        "patterns" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsMatchPatterns" = {
      options = {
        "literal" = mkOption {
          description = "Literal exactly matches the input string (case sensitive).\nIs required if `type` is `literal`.";
          type = types.nullOr types.str;
        };
        "regexp" = mkOption {
          description = "Regexp to match against the input string.\nIs required if `type` is `regexp`.";
          type = types.nullOr types.str;
        };
        "result" = mkOption {
          description = "The value that is used as result of the transform if the pattern matches.";
          type = types.attrs;
        };
        "type" = mkOption {
          description = "Type specifies how the pattern matches the input.\n\n* `literal` - the pattern value has to exactly match (case sensitive) the\ninput string. This is the default.\n\n* `regexp` - the pattern treated as a regular expression against\nwhich the input string is tested. Crossplane will throw an error if the\nkey is not a valid regexp.";
          type = types.str;
        };
      };

      config = {
        "literal" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsMath" = {
      options = {
        "clampMax" = mkOption {
          description = "ClampMax makes sure that the value is not bigger than the given value.";
          type = types.nullOr types.int;
        };
        "clampMin" = mkOption {
          description = "ClampMin makes sure that the value is not smaller than the given value.";
          type = types.nullOr types.int;
        };
        "multiply" = mkOption {
          description = "Multiply the value.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "Type of the math transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clampMax" = mkOverride 1002 null;
        "clampMin" = mkOverride 1002 null;
        "multiply" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsString" = {
      options = {
        "convert" = mkOption {
          description = "Optional conversion method to be specified.\n`ToUpper` and `ToLower` change the letter case of the input string.\n`ToBase64` and `FromBase64` perform a base64 conversion based on the input string.\n`ToJson` converts any input value into its raw JSON representation.\n`ToSha1`, `ToSha256` and `ToSha512` generate a hash value based on the input\nconverted to JSON.\n`ToAdler32` generate a addler32 hash based on the input string.";
          type = types.nullOr types.str;
        };
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.nullOr types.str;
        };
        "join" = mkOption {
          description = "Join defines parameters to join a slice of values to a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsStringJoin");
        };
        "regexp" = mkOption {
          description = "Extract a match from the input using a regular expression.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsStringRegexp");
        };
        "trim" = mkOption {
          description = "Trim the prefix or suffix from the input";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type of the string transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "fmt" = mkOverride 1002 null;
        "join" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
        "trim" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsStringJoin" = {
      options = {
        "separator" = mkOption {
          description = "Separator defines the character that should separate the values from each\nother in the joined string.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPatchSetsPatchesTransformsStringRegexp" = {
      options = {
        "group" = mkOption {
          description = "Group number to match. 0 (the default) matches the entire expression.";
          type = types.nullOr types.int;
        };
        "match" = mkOption {
          description = "Match string. May optionally include submatches, aka capture groups.\nSee https://pkg.go.dev/regexp/ for details.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPipeline" = {
      options = {
        "credentials" = mkOption {
          description = "Credentials are optional credentials that the Composition Function needs.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionSpecPipelineCredentials" "name" ["name"]);
          apply = attrsToList;
        };
        "functionRef" = mkOption {
          description = "FunctionRef is a reference to the Composition Function this step should\nexecute.";
          type = submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPipelineFunctionRef";
        };
        "input" = mkOption {
          description = "Input is an optional, arbitrary Kubernetes resource (i.e. a resource\nwith an apiVersion and kind) that will be passed to the Composition\nFunction as the 'input' of its RunFunctionRequest.";
          type = types.nullOr types.attrs;
        };
        "step" = mkOption {
          description = "Step name. Must be unique within its Pipeline.";
          type = types.str;
        };
      };

      config = {
        "credentials" = mkOverride 1002 null;
        "input" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPipelineCredentials" = {
      options = {
        "name" = mkOption {
          description = "Name of this set of credentials.";
          type = types.str;
        };
        "secretRef" = mkOption {
          description = "A SecretRef is a reference to a secret containing credentials that should\nbe supplied to the function.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecPipelineCredentialsSecretRef");
        };
        "source" = mkOption {
          description = "Source of the function credentials.";
          type = types.str;
        };
      };

      config = {
        "secretRef" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPipelineCredentialsSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace of the secret.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPipelineFunctionRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referenced Function.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecPublishConnectionDetailsWithStoreConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referenced StoreConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResources" = {
      options = {
        "base" = mkOption {
          description = "Base is the target resource that the patches will be applied on.";
          type = types.attrs;
        };
        "connectionDetails" = mkOption {
          description = "ConnectionDetails lists the propagation secret keys from this target\nresource to the composition instance connection secret.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1.CompositionSpecResourcesConnectionDetails" "name" []);
          apply = attrsToList;
        };
        "name" = mkOption {
          description = "A Name uniquely identifies this entry within its Composition's resources\narray. Names are optional but *strongly* recommended. When all entries in\nthe resources array are named entries may added, deleted, and reordered\nas long as their names do not change. When entries are not named the\nlength and order of the resources array should be treated as immutable.\nEither all or no entries must be named.";
          type = types.nullOr types.str;
        };
        "patches" = mkOption {
          description = "Patches will be applied as overlay to the base resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatches"));
        };
        "readinessChecks" = mkOption {
          description = "ReadinessChecks allows users to define custom readiness checks. All checks\nhave to return true in order for resource to be considered ready. The\ndefault readiness check is to have the \"Ready\" condition to be \"True\".";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesReadinessChecks"));
        };
      };

      config = {
        "connectionDetails" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "patches" = mkOverride 1002 null;
        "readinessChecks" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesConnectionDetails" = {
      options = {
        "fromConnectionSecretKey" = mkOption {
          description = "FromConnectionSecretKey is the key that will be used to fetch the value\nfrom the composed resource's connection secret.";
          type = types.nullOr types.str;
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the composed resource whose\nvalue to be used as input. Name must be specified if the type is\nFromFieldPath.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the connection secret key that will be propagated to the\nconnection secret of the composition instance. Leave empty if you'd like\nto use the same key name.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type sets the connection detail fetching behaviour to be used. Each\nconnection detail type may require its own fields to be set on the\nConnectionDetail object. If the type is omitted Crossplane will attempt\nto infer it based on which other fields were specified. If multiple\nfields are specified the order of precedence is:\n1. FromValue\n2. FromConnectionSecretKey\n3. FromFieldPath";
          type = types.nullOr types.str;
        };
        "value" = mkOption {
          description = "Value that will be propagated to the connection secret of the composite\nresource. May be set to inject a fixed, non-sensitive connection secret\nvalue, for example a well-known port.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fromConnectionSecretKey" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatches" = {
      options = {
        "combine" = mkOption {
          description = "Combine is the patch configuration for a CombineFromComposite or\nCombineToComposite patch.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesCombine");
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the resource whose value is\nto be used as input. Required when type is FromCompositeFieldPath or\nToCompositeFieldPath.";
          type = types.nullOr types.str;
        };
        "patchSetName" = mkOption {
          description = "PatchSetName to include patches from. Required when type is PatchSet.";
          type = types.nullOr types.str;
        };
        "policy" = mkOption {
          description = "Policy configures the specifics of patching behaviour.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesPolicy");
        };
        "toFieldPath" = mkOption {
          description = "ToFieldPath is the path of the field on the resource whose value will\nbe changed with the result of transforms. Leave empty if you'd like to\npropagate to the same path as fromFieldPath.";
          type = types.nullOr types.str;
        };
        "transforms" = mkOption {
          description = "Transforms are the list of functions that are used as a FIFO pipe for the\ninput to be transformed.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransforms"));
        };
        "type" = mkOption {
          description = "Type sets the patching behaviour to be used. Each patch type may require\nits own fields to be set on the Patch object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "combine" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "patchSetName" = mkOverride 1002 null;
        "policy" = mkOverride 1002 null;
        "toFieldPath" = mkOverride 1002 null;
        "transforms" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesCombine" = {
      options = {
        "strategy" = mkOption {
          description = "Strategy defines the strategy to use to combine the input variable values.\nCurrently only string is supported.";
          type = types.str;
        };
        "string" = mkOption {
          description = "String declares that input variables should be combined into a single\nstring, using the relevant settings for formatting purposes.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesCombineString");
        };
        "variables" = mkOption {
          description = "Variables are the list of variables whose values will be retrieved and\ncombined.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesCombineVariables");
        };
      };

      config = {
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesCombineString" = {
      options = {
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesCombineVariables" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the source whose value is\nto be used as input.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesPolicy" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath specifies how to patch from a field path. The default is\n'Optional', which means the patch will be a no-op if the specified\nfromFieldPath does not exist. Use 'Required' if the patch should fail if\nthe specified path does not exist.";
          type = types.nullOr types.str;
        };
        "mergeOptions" = mkOption {
          description = "MergeOptions Specifies merge options on a field path.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesPolicyMergeOptions");
        };
      };

      config = {
        "fromFieldPath" = mkOverride 1002 null;
        "mergeOptions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesPolicyMergeOptions" = {
      options = {
        "appendSlice" = mkOption {
          description = "Specifies that already existing elements in a merged slice should be preserved";
          type = types.nullOr types.bool;
        };
        "keepMapValues" = mkOption {
          description = "Specifies that already existing values in a merged map should be preserved";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "appendSlice" = mkOverride 1002 null;
        "keepMapValues" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransforms" = {
      options = {
        "convert" = mkOption {
          description = "Convert is used to cast the input into the given output type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsConvert");
        };
        "map" = mkOption {
          description = "Map uses the input as a key in the given map and returns the value.";
          type = types.nullOr types.attrs;
        };
        "match" = mkOption {
          description = "Match is a more complex version of Map that matches a list of patterns.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsMatch");
        };
        "math" = mkOption {
          description = "Math is used to transform the input via mathematical operations such as\nmultiplication.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsMath");
        };
        "string" = mkOption {
          description = "String is used to transform the input into a string or a different kind\nof string. Note that the input does not necessarily need to be a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsString");
        };
        "type" = mkOption {
          description = "Type of the transform to be run.";
          type = types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "map" = mkOverride 1002 null;
        "match" = mkOverride 1002 null;
        "math" = mkOverride 1002 null;
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsConvert" = {
      options = {
        "format" = mkOption {
          description = "The expected input format.\n\n* `quantity` - parses the input as a K8s [`resource.Quantity`](https://pkg.go.dev/k8s.io/apimachinery/pkg/api/resource#Quantity).\nOnly used during `string -> float64` conversions.\n* `json` - parses the input as a JSON string.\nOnly used during `string -> object` or `string -> list` conversions.\n\nIf this property is null, the default conversion is applied.";
          type = types.nullOr types.str;
        };
        "toType" = mkOption {
          description = "ToType is the type of the output of this transform.";
          type = types.str;
        };
      };

      config = {
        "format" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsMatch" = {
      options = {
        "fallbackTo" = mkOption {
          description = "Determines to what value the transform should fallback if no pattern matches.";
          type = types.nullOr types.str;
        };
        "fallbackValue" = mkOption {
          description = "The fallback value that should be returned by the transform if now pattern\nmatches.";
          type = types.nullOr types.attrs;
        };
        "patterns" = mkOption {
          description = "The patterns that should be tested against the input string.\nPatterns are tested in order. The value of the first match is used as\nresult of this transform.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsMatchPatterns"));
        };
      };

      config = {
        "fallbackTo" = mkOverride 1002 null;
        "fallbackValue" = mkOverride 1002 null;
        "patterns" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsMatchPatterns" = {
      options = {
        "literal" = mkOption {
          description = "Literal exactly matches the input string (case sensitive).\nIs required if `type` is `literal`.";
          type = types.nullOr types.str;
        };
        "regexp" = mkOption {
          description = "Regexp to match against the input string.\nIs required if `type` is `regexp`.";
          type = types.nullOr types.str;
        };
        "result" = mkOption {
          description = "The value that is used as result of the transform if the pattern matches.";
          type = types.attrs;
        };
        "type" = mkOption {
          description = "Type specifies how the pattern matches the input.\n\n* `literal` - the pattern value has to exactly match (case sensitive) the\ninput string. This is the default.\n\n* `regexp` - the pattern treated as a regular expression against\nwhich the input string is tested. Crossplane will throw an error if the\nkey is not a valid regexp.";
          type = types.str;
        };
      };

      config = {
        "literal" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsMath" = {
      options = {
        "clampMax" = mkOption {
          description = "ClampMax makes sure that the value is not bigger than the given value.";
          type = types.nullOr types.int;
        };
        "clampMin" = mkOption {
          description = "ClampMin makes sure that the value is not smaller than the given value.";
          type = types.nullOr types.int;
        };
        "multiply" = mkOption {
          description = "Multiply the value.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "Type of the math transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clampMax" = mkOverride 1002 null;
        "clampMin" = mkOverride 1002 null;
        "multiply" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsString" = {
      options = {
        "convert" = mkOption {
          description = "Optional conversion method to be specified.\n`ToUpper` and `ToLower` change the letter case of the input string.\n`ToBase64` and `FromBase64` perform a base64 conversion based on the input string.\n`ToJson` converts any input value into its raw JSON representation.\n`ToSha1`, `ToSha256` and `ToSha512` generate a hash value based on the input\nconverted to JSON.\n`ToAdler32` generate a addler32 hash based on the input string.";
          type = types.nullOr types.str;
        };
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.nullOr types.str;
        };
        "join" = mkOption {
          description = "Join defines parameters to join a slice of values to a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsStringJoin");
        };
        "regexp" = mkOption {
          description = "Extract a match from the input using a regular expression.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsStringRegexp");
        };
        "trim" = mkOption {
          description = "Trim the prefix or suffix from the input";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type of the string transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "fmt" = mkOverride 1002 null;
        "join" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
        "trim" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsStringJoin" = {
      options = {
        "separator" = mkOption {
          description = "Separator defines the character that should separate the values from each\nother in the joined string.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesPatchesTransformsStringRegexp" = {
      options = {
        "group" = mkOption {
          description = "Group number to match. 0 (the default) matches the entire expression.";
          type = types.nullOr types.int;
        };
        "match" = mkOption {
          description = "Match string. May optionally include submatches, aka capture groups.\nSee https://pkg.go.dev/regexp/ for details.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesReadinessChecks" = {
      options = {
        "fieldPath" = mkOption {
          description = "FieldPath shows the path of the field whose value will be used.";
          type = types.nullOr types.str;
        };
        "matchCondition" = mkOption {
          description = "MatchCondition specifies the condition you'd like to match if you're using \"MatchCondition\" type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1.CompositionSpecResourcesReadinessChecksMatchCondition");
        };
        "matchInteger" = mkOption {
          description = "MatchInt is the value you'd like to match if you're using \"MatchInt\" type.";
          type = types.nullOr types.int;
        };
        "matchString" = mkOption {
          description = "MatchString is the value you'd like to match if you're using \"MatchString\" type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type indicates the type of probe you'd like to use.";
          type = types.str;
        };
      };

      config = {
        "fieldPath" = mkOverride 1002 null;
        "matchCondition" = mkOverride 1002 null;
        "matchInteger" = mkOverride 1002 null;
        "matchString" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1.CompositionSpecResourcesReadinessChecksMatchCondition" = {
      options = {
        "status" = mkOption {
          description = "Status is the status of the condition you'd like to match.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type indicates the type of condition you'd like to use.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1alpha1.EnvironmentConfig" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "data" = mkOption {
          description = "The data of this EnvironmentConfig.\nThis may contain any kind of structure that can be serialized into JSON.";
          type = types.nullOr types.attrs;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "data" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.Usage" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "UsageSpec defines the desired state of Usage.";
          type = submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpec";
        };
        "status" = mkOption {
          description = "UsageStatus defines the observed state of Usage.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpec" = {
      options = {
        "by" = mkOption {
          description = "By is the resource that is \"using the other resource\".";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpecBy");
        };
        "of" = mkOption {
          description = "Of is the resource that is \"being used\".";
          type = submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpecOf";
        };
        "reason" = mkOption {
          description = "Reason is the reason for blocking deletion of the resource.";
          type = types.nullOr types.str;
        };
        "replayDeletion" = mkOption {
          description = "ReplayDeletion will trigger a deletion on the used resource during the deletion of the usage itself, if it was attempted to be deleted at least once.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "by" = mkOverride 1002 null;
        "reason" = mkOverride 1002 null;
        "replayDeletion" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpecBy" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "resourceRef" = mkOption {
          description = "Reference to the resource.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpecByResourceRef");
        };
        "resourceSelector" = mkOption {
          description = "Selector to the resource.\nThis field will be ignored if ResourceRef is set.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpecByResourceSelector");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "resourceRef" = mkOverride 1002 null;
        "resourceSelector" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpecByResourceRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpecByResourceSelector" = {
      options = {
        "matchControllerRef" = mkOption {
          description = "MatchControllerRef ensures an object with the same controller reference\nas the selecting object is selected.";
          type = types.nullOr types.bool;
        };
        "matchLabels" = mkOption {
          description = "MatchLabels ensures an object with matching labels is selected.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchControllerRef" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpecOf" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "resourceRef" = mkOption {
          description = "Reference to the resource.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpecOfResourceRef");
        };
        "resourceSelector" = mkOption {
          description = "Selector to the resource.\nThis field will be ignored if ResourceRef is set.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageSpecOfResourceSelector");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "resourceRef" = mkOverride 1002 null;
        "resourceSelector" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpecOfResourceRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1alpha1.UsageSpecOfResourceSelector" = {
      options = {
        "matchControllerRef" = mkOption {
          description = "MatchControllerRef ensures an object with the same controller reference\nas the selecting object is selected.";
          type = types.nullOr types.bool;
        };
        "matchLabels" = mkOption {
          description = "MatchLabels ensures an object with matching labels is selected.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchControllerRef" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1alpha1.UsageStatusConditions"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1alpha1.UsageStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevision" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "CompositionRevisionSpec specifies the desired state of the composition\nrevision.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpec");
        };
        "status" = mkOption {
          description = "CompositionRevisionStatus shows the observed state of the composition\nrevision.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpec" = {
      options = {
        "compositeTypeRef" = mkOption {
          description = "CompositeTypeRef specifies the type of composite resource that this\ncomposition is compatible with.";
          type = submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecCompositeTypeRef";
        };
        "mode" = mkOption {
          description = "Mode controls what type or \"mode\" of Composition will be used.\n\n\"Pipeline\" indicates that a Composition specifies a pipeline of\nComposition Functions, each of which is responsible for producing\ncomposed resources that Crossplane should create or update.\n\n\"Resources\" indicates that a Composition uses what is commonly referred\nto as \"Patch & Transform\" or P&T composition. This mode of Composition\nuses an array of resources, each a template for a composed resource.\n\nAll Compositions should use Pipeline mode. Resources mode is deprecated.\nResources mode won't be removed in Crossplane 1.x, and will remain the\ndefault to avoid breaking legacy Compositions. However, it's no longer\naccepting new features, and only accepting security related bug fixes.";
          type = types.nullOr types.str;
        };
        "patchSets" = mkOption {
          description = "PatchSets define a named set of patches that may be included by any\nresource in this Composition. PatchSets cannot themselves refer to other\nPatchSets.\n\nPatchSets are only used by the \"Resources\" mode of Composition. They\nare ignored by other modes.\n\nDeprecated: Use Composition Functions instead.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSets" "name" []);
          apply = attrsToList;
        };
        "pipeline" = mkOption {
          description = "Pipeline is a list of composition function steps that will be used when a\ncomposite resource referring to this composition is created. One of\nresources and pipeline must be specified - you cannot specify both.\n\nThe Pipeline is only used by the \"Pipeline\" mode of Composition. It is\nignored by other modes.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipeline"));
        };
        "publishConnectionDetailsWithStoreConfigRef" = mkOption {
          description = "PublishConnectionDetailsWithStoreConfig specifies the secret store config\nwith which the connection details of composite resources dynamically\nprovisioned using this composition will be published.\n\nTHIS IS AN ALPHA FIELD. Do not use it in production. It is not honored\nunless the relevant Crossplane feature flag is enabled, and may be\nchanged or removed without notice.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPublishConnectionDetailsWithStoreConfigRef");
        };
        "resources" = mkOption {
          description = "Resources is a list of resource templates that will be used when a\ncomposite resource referring to this composition is created.\n\nResources are only used by the \"Resources\" mode of Composition. They are\nignored by other modes.\n\nDeprecated: Use Composition Functions instead.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResources" "name" []);
          apply = attrsToList;
        };
        "revision" = mkOption {
          description = "Revision number. Newer revisions have larger numbers.\n\nThis number can change. When a Composition transitions from state A\n-> B -> A there will be only two CompositionRevisions. Crossplane will\nedit the original CompositionRevision to change its revision number from\n0 to 2.";
          type = types.int;
        };
        "writeConnectionSecretsToNamespace" = mkOption {
          description = "WriteConnectionSecretsToNamespace specifies the namespace in which the\nconnection secrets of composite resource dynamically provisioned using\nthis composition will be created.\nThis field is planned to be replaced in a future release in favor of\nPublishConnectionDetailsWithStoreConfigRef. Currently, both could be\nset independently and connection details would be published to both\nwithout affecting each other as long as related fields at MR level\nspecified.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
        "patchSets" = mkOverride 1002 null;
        "pipeline" = mkOverride 1002 null;
        "publishConnectionDetailsWithStoreConfigRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "writeConnectionSecretsToNamespace" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecCompositeTypeRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the type.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the type.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSets" = {
      options = {
        "name" = mkOption {
          description = "Name of this PatchSet.";
          type = types.str;
        };
        "patches" = mkOption {
          description = "Patches will be applied as an overlay to the base resource.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatches");
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatches" = {
      options = {
        "combine" = mkOption {
          description = "Combine is the patch configuration for a CombineFromComposite or\nCombineToComposite patch.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesCombine");
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the resource whose value is\nto be used as input. Required when type is FromCompositeFieldPath or\nToCompositeFieldPath.";
          type = types.nullOr types.str;
        };
        "patchSetName" = mkOption {
          description = "PatchSetName to include patches from. Required when type is PatchSet.";
          type = types.nullOr types.str;
        };
        "policy" = mkOption {
          description = "Policy configures the specifics of patching behaviour.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesPolicy");
        };
        "toFieldPath" = mkOption {
          description = "ToFieldPath is the path of the field on the resource whose value will\nbe changed with the result of transforms. Leave empty if you'd like to\npropagate to the same path as fromFieldPath.";
          type = types.nullOr types.str;
        };
        "transforms" = mkOption {
          description = "Transforms are the list of functions that are used as a FIFO pipe for the\ninput to be transformed.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransforms"));
        };
        "type" = mkOption {
          description = "Type sets the patching behaviour to be used. Each patch type may require\nits own fields to be set on the Patch object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "combine" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "patchSetName" = mkOverride 1002 null;
        "policy" = mkOverride 1002 null;
        "toFieldPath" = mkOverride 1002 null;
        "transforms" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesCombine" = {
      options = {
        "strategy" = mkOption {
          description = "Strategy defines the strategy to use to combine the input variable values.\nCurrently only string is supported.";
          type = types.str;
        };
        "string" = mkOption {
          description = "String declares that input variables should be combined into a single\nstring, using the relevant settings for formatting purposes.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesCombineString");
        };
        "variables" = mkOption {
          description = "Variables are the list of variables whose values will be retrieved and\ncombined.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesCombineVariables");
        };
      };

      config = {
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesCombineString" = {
      options = {
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesCombineVariables" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the source whose value is\nto be used as input.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesPolicy" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath specifies how to patch from a field path. The default is\n'Optional', which means the patch will be a no-op if the specified\nfromFieldPath does not exist. Use 'Required' if the patch should fail if\nthe specified path does not exist.";
          type = types.nullOr types.str;
        };
        "mergeOptions" = mkOption {
          description = "MergeOptions Specifies merge options on a field path.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesPolicyMergeOptions");
        };
      };

      config = {
        "fromFieldPath" = mkOverride 1002 null;
        "mergeOptions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesPolicyMergeOptions" = {
      options = {
        "appendSlice" = mkOption {
          description = "Specifies that already existing elements in a merged slice should be preserved";
          type = types.nullOr types.bool;
        };
        "keepMapValues" = mkOption {
          description = "Specifies that already existing values in a merged map should be preserved";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "appendSlice" = mkOverride 1002 null;
        "keepMapValues" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransforms" = {
      options = {
        "convert" = mkOption {
          description = "Convert is used to cast the input into the given output type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsConvert");
        };
        "map" = mkOption {
          description = "Map uses the input as a key in the given map and returns the value.";
          type = types.nullOr types.attrs;
        };
        "match" = mkOption {
          description = "Match is a more complex version of Map that matches a list of patterns.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsMatch");
        };
        "math" = mkOption {
          description = "Math is used to transform the input via mathematical operations such as\nmultiplication.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsMath");
        };
        "string" = mkOption {
          description = "String is used to transform the input into a string or a different kind\nof string. Note that the input does not necessarily need to be a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsString");
        };
        "type" = mkOption {
          description = "Type of the transform to be run.";
          type = types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "map" = mkOverride 1002 null;
        "match" = mkOverride 1002 null;
        "math" = mkOverride 1002 null;
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsConvert" = {
      options = {
        "format" = mkOption {
          description = "The expected input format.\n\n* `quantity` - parses the input as a K8s [`resource.Quantity`](https://pkg.go.dev/k8s.io/apimachinery/pkg/api/resource#Quantity).\nOnly used during `string -> float64` conversions.\n* `json` - parses the input as a JSON string.\nOnly used during `string -> object` or `string -> list` conversions.\n\nIf this property is null, the default conversion is applied.";
          type = types.nullOr types.str;
        };
        "toType" = mkOption {
          description = "ToType is the type of the output of this transform.";
          type = types.str;
        };
      };

      config = {
        "format" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsMatch" = {
      options = {
        "fallbackTo" = mkOption {
          description = "Determines to what value the transform should fallback if no pattern matches.";
          type = types.nullOr types.str;
        };
        "fallbackValue" = mkOption {
          description = "The fallback value that should be returned by the transform if now pattern\nmatches.";
          type = types.nullOr types.attrs;
        };
        "patterns" = mkOption {
          description = "The patterns that should be tested against the input string.\nPatterns are tested in order. The value of the first match is used as\nresult of this transform.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsMatchPatterns"));
        };
      };

      config = {
        "fallbackTo" = mkOverride 1002 null;
        "fallbackValue" = mkOverride 1002 null;
        "patterns" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsMatchPatterns" = {
      options = {
        "literal" = mkOption {
          description = "Literal exactly matches the input string (case sensitive).\nIs required if `type` is `literal`.";
          type = types.nullOr types.str;
        };
        "regexp" = mkOption {
          description = "Regexp to match against the input string.\nIs required if `type` is `regexp`.";
          type = types.nullOr types.str;
        };
        "result" = mkOption {
          description = "The value that is used as result of the transform if the pattern matches.";
          type = types.attrs;
        };
        "type" = mkOption {
          description = "Type specifies how the pattern matches the input.\n\n* `literal` - the pattern value has to exactly match (case sensitive) the\ninput string. This is the default.\n\n* `regexp` - the pattern treated as a regular expression against\nwhich the input string is tested. Crossplane will throw an error if the\nkey is not a valid regexp.";
          type = types.str;
        };
      };

      config = {
        "literal" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsMath" = {
      options = {
        "clampMax" = mkOption {
          description = "ClampMax makes sure that the value is not bigger than the given value.";
          type = types.nullOr types.int;
        };
        "clampMin" = mkOption {
          description = "ClampMin makes sure that the value is not smaller than the given value.";
          type = types.nullOr types.int;
        };
        "multiply" = mkOption {
          description = "Multiply the value.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "Type of the math transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clampMax" = mkOverride 1002 null;
        "clampMin" = mkOverride 1002 null;
        "multiply" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsString" = {
      options = {
        "convert" = mkOption {
          description = "Optional conversion method to be specified.\n`ToUpper` and `ToLower` change the letter case of the input string.\n`ToBase64` and `FromBase64` perform a base64 conversion based on the input string.\n`ToJson` converts any input value into its raw JSON representation.\n`ToSha1`, `ToSha256` and `ToSha512` generate a hash value based on the input\nconverted to JSON.\n`ToAdler32` generate a addler32 hash based on the input string.";
          type = types.nullOr types.str;
        };
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.nullOr types.str;
        };
        "join" = mkOption {
          description = "Join defines parameters to join a slice of values to a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsStringJoin");
        };
        "regexp" = mkOption {
          description = "Extract a match from the input using a regular expression.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsStringRegexp");
        };
        "trim" = mkOption {
          description = "Trim the prefix or suffix from the input";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type of the string transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "fmt" = mkOverride 1002 null;
        "join" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
        "trim" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsStringJoin" = {
      options = {
        "separator" = mkOption {
          description = "Separator defines the character that should separate the values from each\nother in the joined string.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPatchSetsPatchesTransformsStringRegexp" = {
      options = {
        "group" = mkOption {
          description = "Group number to match. 0 (the default) matches the entire expression.";
          type = types.nullOr types.int;
        };
        "match" = mkOption {
          description = "Match string. May optionally include submatches, aka capture groups.\nSee https://pkg.go.dev/regexp/ for details.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipeline" = {
      options = {
        "credentials" = mkOption {
          description = "Credentials are optional credentials that the Composition Function needs.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipelineCredentials" "name" ["name"]);
          apply = attrsToList;
        };
        "functionRef" = mkOption {
          description = "FunctionRef is a reference to the Composition Function this step should\nexecute.";
          type = submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipelineFunctionRef";
        };
        "input" = mkOption {
          description = "Input is an optional, arbitrary Kubernetes resource (i.e. a resource\nwith an apiVersion and kind) that will be passed to the Composition\nFunction as the 'input' of its RunFunctionRequest.";
          type = types.nullOr types.attrs;
        };
        "step" = mkOption {
          description = "Step name. Must be unique within its Pipeline.";
          type = types.str;
        };
      };

      config = {
        "credentials" = mkOverride 1002 null;
        "input" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipelineCredentials" = {
      options = {
        "name" = mkOption {
          description = "Name of this set of credentials.";
          type = types.str;
        };
        "secretRef" = mkOption {
          description = "A SecretRef is a reference to a secret containing credentials that should\nbe supplied to the function.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipelineCredentialsSecretRef");
        };
        "source" = mkOption {
          description = "Source of the function credentials.";
          type = types.str;
        };
      };

      config = {
        "secretRef" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipelineCredentialsSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace of the secret.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPipelineFunctionRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referenced Function.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecPublishConnectionDetailsWithStoreConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referenced StoreConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResources" = {
      options = {
        "base" = mkOption {
          description = "Base is the target resource that the patches will be applied on.";
          type = types.attrs;
        };
        "connectionDetails" = mkOption {
          description = "ConnectionDetails lists the propagation secret keys from this target\nresource to the composition instance connection secret.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesConnectionDetails" "name" []);
          apply = attrsToList;
        };
        "name" = mkOption {
          description = "A Name uniquely identifies this entry within its Composition's resources\narray. Names are optional but *strongly* recommended. When all entries in\nthe resources array are named entries may added, deleted, and reordered\nas long as their names do not change. When entries are not named the\nlength and order of the resources array should be treated as immutable.\nEither all or no entries must be named.";
          type = types.nullOr types.str;
        };
        "patches" = mkOption {
          description = "Patches will be applied as overlay to the base resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatches"));
        };
        "readinessChecks" = mkOption {
          description = "ReadinessChecks allows users to define custom readiness checks. All checks\nhave to return true in order for resource to be considered ready. The\ndefault readiness check is to have the \"Ready\" condition to be \"True\".";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesReadinessChecks"));
        };
      };

      config = {
        "connectionDetails" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "patches" = mkOverride 1002 null;
        "readinessChecks" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesConnectionDetails" = {
      options = {
        "fromConnectionSecretKey" = mkOption {
          description = "FromConnectionSecretKey is the key that will be used to fetch the value\nfrom the composed resource's connection secret.";
          type = types.nullOr types.str;
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the composed resource whose\nvalue to be used as input. Name must be specified if the type is\nFromFieldPath.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the connection secret key that will be propagated to the\nconnection secret of the composition instance. Leave empty if you'd like\nto use the same key name.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type sets the connection detail fetching behaviour to be used. Each\nconnection detail type may require its own fields to be set on the\nConnectionDetail object. If the type is omitted Crossplane will attempt\nto infer it based on which other fields were specified. If multiple\nfields are specified the order of precedence is:\n1. FromValue\n2. FromConnectionSecretKey\n3. FromFieldPath";
          type = types.nullOr types.str;
        };
        "value" = mkOption {
          description = "Value that will be propagated to the connection secret of the composite\nresource. May be set to inject a fixed, non-sensitive connection secret\nvalue, for example a well-known port.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fromConnectionSecretKey" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatches" = {
      options = {
        "combine" = mkOption {
          description = "Combine is the patch configuration for a CombineFromComposite or\nCombineToComposite patch.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesCombine");
        };
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the resource whose value is\nto be used as input. Required when type is FromCompositeFieldPath or\nToCompositeFieldPath.";
          type = types.nullOr types.str;
        };
        "patchSetName" = mkOption {
          description = "PatchSetName to include patches from. Required when type is PatchSet.";
          type = types.nullOr types.str;
        };
        "policy" = mkOption {
          description = "Policy configures the specifics of patching behaviour.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesPolicy");
        };
        "toFieldPath" = mkOption {
          description = "ToFieldPath is the path of the field on the resource whose value will\nbe changed with the result of transforms. Leave empty if you'd like to\npropagate to the same path as fromFieldPath.";
          type = types.nullOr types.str;
        };
        "transforms" = mkOption {
          description = "Transforms are the list of functions that are used as a FIFO pipe for the\ninput to be transformed.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransforms"));
        };
        "type" = mkOption {
          description = "Type sets the patching behaviour to be used. Each patch type may require\nits own fields to be set on the Patch object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "combine" = mkOverride 1002 null;
        "fromFieldPath" = mkOverride 1002 null;
        "patchSetName" = mkOverride 1002 null;
        "policy" = mkOverride 1002 null;
        "toFieldPath" = mkOverride 1002 null;
        "transforms" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesCombine" = {
      options = {
        "strategy" = mkOption {
          description = "Strategy defines the strategy to use to combine the input variable values.\nCurrently only string is supported.";
          type = types.str;
        };
        "string" = mkOption {
          description = "String declares that input variables should be combined into a single\nstring, using the relevant settings for formatting purposes.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesCombineString");
        };
        "variables" = mkOption {
          description = "Variables are the list of variables whose values will be retrieved and\ncombined.";
          type = types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesCombineVariables");
        };
      };

      config = {
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesCombineString" = {
      options = {
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesCombineVariables" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath is the path of the field on the source whose value is\nto be used as input.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesPolicy" = {
      options = {
        "fromFieldPath" = mkOption {
          description = "FromFieldPath specifies how to patch from a field path. The default is\n'Optional', which means the patch will be a no-op if the specified\nfromFieldPath does not exist. Use 'Required' if the patch should fail if\nthe specified path does not exist.";
          type = types.nullOr types.str;
        };
        "mergeOptions" = mkOption {
          description = "MergeOptions Specifies merge options on a field path.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesPolicyMergeOptions");
        };
      };

      config = {
        "fromFieldPath" = mkOverride 1002 null;
        "mergeOptions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesPolicyMergeOptions" = {
      options = {
        "appendSlice" = mkOption {
          description = "Specifies that already existing elements in a merged slice should be preserved";
          type = types.nullOr types.bool;
        };
        "keepMapValues" = mkOption {
          description = "Specifies that already existing values in a merged map should be preserved";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "appendSlice" = mkOverride 1002 null;
        "keepMapValues" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransforms" = {
      options = {
        "convert" = mkOption {
          description = "Convert is used to cast the input into the given output type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsConvert");
        };
        "map" = mkOption {
          description = "Map uses the input as a key in the given map and returns the value.";
          type = types.nullOr types.attrs;
        };
        "match" = mkOption {
          description = "Match is a more complex version of Map that matches a list of patterns.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsMatch");
        };
        "math" = mkOption {
          description = "Math is used to transform the input via mathematical operations such as\nmultiplication.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsMath");
        };
        "string" = mkOption {
          description = "String is used to transform the input into a string or a different kind\nof string. Note that the input does not necessarily need to be a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsString");
        };
        "type" = mkOption {
          description = "Type of the transform to be run.";
          type = types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "map" = mkOverride 1002 null;
        "match" = mkOverride 1002 null;
        "math" = mkOverride 1002 null;
        "string" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsConvert" = {
      options = {
        "format" = mkOption {
          description = "The expected input format.\n\n* `quantity` - parses the input as a K8s [`resource.Quantity`](https://pkg.go.dev/k8s.io/apimachinery/pkg/api/resource#Quantity).\nOnly used during `string -> float64` conversions.\n* `json` - parses the input as a JSON string.\nOnly used during `string -> object` or `string -> list` conversions.\n\nIf this property is null, the default conversion is applied.";
          type = types.nullOr types.str;
        };
        "toType" = mkOption {
          description = "ToType is the type of the output of this transform.";
          type = types.str;
        };
      };

      config = {
        "format" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsMatch" = {
      options = {
        "fallbackTo" = mkOption {
          description = "Determines to what value the transform should fallback if no pattern matches.";
          type = types.nullOr types.str;
        };
        "fallbackValue" = mkOption {
          description = "The fallback value that should be returned by the transform if now pattern\nmatches.";
          type = types.nullOr types.attrs;
        };
        "patterns" = mkOption {
          description = "The patterns that should be tested against the input string.\nPatterns are tested in order. The value of the first match is used as\nresult of this transform.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsMatchPatterns"));
        };
      };

      config = {
        "fallbackTo" = mkOverride 1002 null;
        "fallbackValue" = mkOverride 1002 null;
        "patterns" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsMatchPatterns" = {
      options = {
        "literal" = mkOption {
          description = "Literal exactly matches the input string (case sensitive).\nIs required if `type` is `literal`.";
          type = types.nullOr types.str;
        };
        "regexp" = mkOption {
          description = "Regexp to match against the input string.\nIs required if `type` is `regexp`.";
          type = types.nullOr types.str;
        };
        "result" = mkOption {
          description = "The value that is used as result of the transform if the pattern matches.";
          type = types.attrs;
        };
        "type" = mkOption {
          description = "Type specifies how the pattern matches the input.\n\n* `literal` - the pattern value has to exactly match (case sensitive) the\ninput string. This is the default.\n\n* `regexp` - the pattern treated as a regular expression against\nwhich the input string is tested. Crossplane will throw an error if the\nkey is not a valid regexp.";
          type = types.str;
        };
      };

      config = {
        "literal" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsMath" = {
      options = {
        "clampMax" = mkOption {
          description = "ClampMax makes sure that the value is not bigger than the given value.";
          type = types.nullOr types.int;
        };
        "clampMin" = mkOption {
          description = "ClampMin makes sure that the value is not smaller than the given value.";
          type = types.nullOr types.int;
        };
        "multiply" = mkOption {
          description = "Multiply the value.";
          type = types.nullOr types.int;
        };
        "type" = mkOption {
          description = "Type of the math transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clampMax" = mkOverride 1002 null;
        "clampMin" = mkOverride 1002 null;
        "multiply" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsString" = {
      options = {
        "convert" = mkOption {
          description = "Optional conversion method to be specified.\n`ToUpper` and `ToLower` change the letter case of the input string.\n`ToBase64` and `FromBase64` perform a base64 conversion based on the input string.\n`ToJson` converts any input value into its raw JSON representation.\n`ToSha1`, `ToSha256` and `ToSha512` generate a hash value based on the input\nconverted to JSON.\n`ToAdler32` generate a addler32 hash based on the input string.";
          type = types.nullOr types.str;
        };
        "fmt" = mkOption {
          description = "Format the input using a Go format string. See\nhttps://golang.org/pkg/fmt/ for details.";
          type = types.nullOr types.str;
        };
        "join" = mkOption {
          description = "Join defines parameters to join a slice of values to a string.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsStringJoin");
        };
        "regexp" = mkOption {
          description = "Extract a match from the input using a regular expression.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsStringRegexp");
        };
        "trim" = mkOption {
          description = "Trim the prefix or suffix from the input";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type of the string transform to be run.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "convert" = mkOverride 1002 null;
        "fmt" = mkOverride 1002 null;
        "join" = mkOverride 1002 null;
        "regexp" = mkOverride 1002 null;
        "trim" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsStringJoin" = {
      options = {
        "separator" = mkOption {
          description = "Separator defines the character that should separate the values from each\nother in the joined string.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesPatchesTransformsStringRegexp" = {
      options = {
        "group" = mkOption {
          description = "Group number to match. 0 (the default) matches the entire expression.";
          type = types.nullOr types.int;
        };
        "match" = mkOption {
          description = "Match string. May optionally include submatches, aka capture groups.\nSee https://pkg.go.dev/regexp/ for details.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesReadinessChecks" = {
      options = {
        "fieldPath" = mkOption {
          description = "FieldPath shows the path of the field whose value will be used.";
          type = types.nullOr types.str;
        };
        "matchCondition" = mkOption {
          description = "MatchCondition specifies the condition you'd like to match if you're using \"MatchCondition\" type.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesReadinessChecksMatchCondition");
        };
        "matchInteger" = mkOption {
          description = "MatchInt is the value you'd like to match if you're using \"MatchInt\" type.";
          type = types.nullOr types.int;
        };
        "matchString" = mkOption {
          description = "MatchString is the value you'd like to match if you're using \"MatchString\" type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type indicates the type of probe you'd like to use.";
          type = types.str;
        };
      };

      config = {
        "fieldPath" = mkOverride 1002 null;
        "matchCondition" = mkOverride 1002 null;
        "matchInteger" = mkOverride 1002 null;
        "matchString" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionSpecResourcesReadinessChecksMatchCondition" = {
      options = {
        "status" = mkOption {
          description = "Status is the status of the condition you'd like to match.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type indicates the type of condition you'd like to use.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.CompositionRevisionStatusConditions"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.CompositionRevisionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.EnvironmentConfig" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "data" = mkOption {
          description = "The data of this EnvironmentConfig.\nThis may contain any kind of structure that can be serialized into JSON.";
          type = types.nullOr types.attrs;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "data" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.Usage" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "UsageSpec defines the desired state of Usage.";
          type = submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpec";
        };
        "status" = mkOption {
          description = "UsageStatus defines the observed state of Usage.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpec" = {
      options = {
        "by" = mkOption {
          description = "By is the resource that is \"using the other resource\".";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpecBy");
        };
        "of" = mkOption {
          description = "Of is the resource that is \"being used\".";
          type = submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpecOf";
        };
        "reason" = mkOption {
          description = "Reason is the reason for blocking deletion of the resource.";
          type = types.nullOr types.str;
        };
        "replayDeletion" = mkOption {
          description = "ReplayDeletion will trigger a deletion on the used resource during the deletion of the usage itself, if it was attempted to be deleted at least once.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "by" = mkOverride 1002 null;
        "reason" = mkOverride 1002 null;
        "replayDeletion" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpecBy" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "resourceRef" = mkOption {
          description = "Reference to the resource.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpecByResourceRef");
        };
        "resourceSelector" = mkOption {
          description = "Selector to the resource.\nThis field will be ignored if ResourceRef is set.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpecByResourceSelector");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "resourceRef" = mkOverride 1002 null;
        "resourceSelector" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpecByResourceRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpecByResourceSelector" = {
      options = {
        "matchControllerRef" = mkOption {
          description = "MatchControllerRef ensures an object with the same controller reference\nas the selecting object is selected.";
          type = types.nullOr types.bool;
        };
        "matchLabels" = mkOption {
          description = "MatchLabels ensures an object with matching labels is selected.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchControllerRef" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpecOf" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "resourceRef" = mkOption {
          description = "Reference to the resource.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpecOfResourceRef");
        };
        "resourceSelector" = mkOption {
          description = "Selector to the resource.\nThis field will be ignored if ResourceRef is set.";
          type = types.nullOr (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageSpecOfResourceSelector");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "resourceRef" = mkOverride 1002 null;
        "resourceSelector" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpecOfResourceRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.";
          type = types.str;
        };
      };

      config = {};
    };
    "apiextensions.crossplane.io.v1beta1.UsageSpecOfResourceSelector" = {
      options = {
        "matchControllerRef" = mkOption {
          description = "MatchControllerRef ensures an object with the same controller reference\nas the selecting object is selected.";
          type = types.nullOr types.bool;
        };
        "matchLabels" = mkOption {
          description = "MatchLabels ensures an object with matching labels is selected.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchControllerRef" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "apiextensions.crossplane.io.v1beta1.UsageStatusConditions"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };
    };
    "apiextensions.crossplane.io.v1beta1.UsageStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.Configuration" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "ConfigurationSpec specifies details about a request to install a\nconfiguration to Crossplane.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ConfigurationSpec");
        };
        "status" = mkOption {
          description = "ConfigurationStatus represents the observed state of a Configuration.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ConfigurationStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevision" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "PackageRevisionSpec specifies the desired state of a PackageRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ConfigurationRevisionSpec");
        };
        "status" = mkOption {
          description = "PackageRevisionStatus represents the observed state of a PackageRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ConfigurationRevisionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevisionSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "desiredState" = mkOption {
          description = "DesiredState of the PackageRevision. Can be either Active or Inactive.";
          type = types.str;
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "image" = mkOption {
          description = "Package image used by install Pod to extract package contents.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package. It is also\napplied to any images pulled for the package, such as a provider's\ncontroller image.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be\nused to fetch packages from private registries. They are also applied to\nany images pulled for the package, such as a provider's controller image.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.ConfigurationRevisionSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revision" = mkOption {
          description = "Revision number. Indicates when the revision will be garbage collected\nbased on the parent's RevisionHistoryLimit.";
          type = types.int;
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevisionSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevisionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.ConfigurationRevisionStatusConditions"));
        };
        "foundDependencies" = mkOption {
          description = "Dependency information.";
          type = types.nullOr types.int;
        };
        "installedDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "invalidDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "objectRefs" = mkOption {
          description = "References to objects owned by PackageRevision.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.ConfigurationRevisionStatusObjectRefs" "name" []);
          apply = attrsToList;
        };
        "permissionRequests" = mkOption {
          description = "PermissionRequests made by this package. The package declares that its\ncontroller needs these permissions to run. The RBAC manager is\nresponsible for granting them.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.ConfigurationRevisionStatusPermissionRequests"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "foundDependencies" = mkOverride 1002 null;
        "installedDependencies" = mkOverride 1002 null;
        "invalidDependencies" = mkOverride 1002 null;
        "objectRefs" = mkOverride 1002 null;
        "permissionRequests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevisionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevisionStatusObjectRefs" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the referenced object.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referenced object.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referenced object.";
          type = types.str;
        };
        "uid" = mkOption {
          description = "UID of the referenced object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "uid" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationRevisionStatusPermissionRequests" = {
      options = {
        "apiGroups" = mkOption {
          description = "APIGroups is the name of the APIGroup that contains the resources.  If multiple API groups are specified, any action requested against one of\nthe enumerated resources in any API group will be allowed. \"\" represents the core API group and \"*\" represents all API groups.";
          type = types.nullOr (types.listOf types.str);
        };
        "nonResourceURLs" = mkOption {
          description = "NonResourceURLs is a set of partial urls that a user should have access to.  *s are allowed, but only as the full, final step in the path\nSince non-resource URLs are not namespaced, this field is only applicable for ClusterRoles referenced from a ClusterRoleBinding.\nRules can either apply to API resources (such as \"pods\" or \"secrets\") or non-resource URL paths (such as \"/api\"),  but not both.";
          type = types.nullOr (types.listOf types.str);
        };
        "resourceNames" = mkOption {
          description = "ResourceNames is an optional white list of names that the rule applies to.  An empty set means that everything is allowed.";
          type = types.nullOr (types.listOf types.str);
        };
        "resources" = mkOption {
          description = "Resources is a list of resources this rule applies to. '*' represents all resources.";
          type = types.nullOr (types.listOf types.str);
        };
        "verbs" = mkOption {
          description = "Verbs is a list of Verbs that apply to ALL the ResourceKinds contained in this rule. '*' represents all verbs.";
          type = types.listOf types.str;
        };
      };

      config = {
        "apiGroups" = mkOverride 1002 null;
        "nonResourceURLs" = mkOverride 1002 null;
        "resourceNames" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "package" = mkOption {
          description = "Package is the name of the package that is being requested.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be used\nto fetch packages from private registries.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.ConfigurationSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revisionActivationPolicy" = mkOption {
          description = "RevisionActivationPolicy specifies how the package controller should\nupdate from one revision to the next. Options are Automatic or Manual.\nDefault is Automatic.";
          type = types.nullOr types.str;
        };
        "revisionHistoryLimit" = mkOption {
          description = "RevisionHistoryLimit dictates how the package controller cleans up old\ninactive package revisions.\nDefaults to 1. Can be disabled by explicitly setting to 0.";
          type = types.nullOr types.int;
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "revisionActivationPolicy" = mkOverride 1002 null;
        "revisionHistoryLimit" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.ConfigurationStatusConditions"));
        };
        "currentIdentifier" = mkOption {
          description = "CurrentIdentifier is the most recent package source that was used to\nproduce a revision. The package manager uses this field to determine\nwhether to check for package updates for a given source when\npackagePullPolicy is set to IfNotPresent. Manually removing this field\nwill cause the package manager to check that the current revision is\ncorrect for the given package source.";
          type = types.nullOr types.str;
        };
        "currentRevision" = mkOption {
          description = "CurrentRevision is the name of the current package revision. It will\nreflect the most up to date revision, whether it has been activated or\nnot.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "currentIdentifier" = mkOverride 1002 null;
        "currentRevision" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ConfigurationStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.Function" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "FunctionSpec specifies the configuration of a Function.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionSpec");
        };
        "status" = mkOption {
          description = "FunctionStatus represents the observed state of a Function.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevision" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "FunctionRevisionSpec specifies configuration for a FunctionRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionRevisionSpec");
        };
        "status" = mkOption {
          description = "FunctionRevisionStatus represents the observed state of a FunctionRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionRevisionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "controllerConfigRef" = mkOption {
          description = "ControllerConfigRef references a ControllerConfig resource that will be\nused to configure the packaged controller Deployment.\nDeprecated: Use RuntimeConfigReference instead.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionRevisionSpecControllerConfigRef");
        };
        "desiredState" = mkOption {
          description = "DesiredState of the PackageRevision. Can be either Active or Inactive.";
          type = types.str;
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "image" = mkOption {
          description = "Package image used by install Pod to extract package contents.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package. It is also\napplied to any images pulled for the package, such as a provider's\ncontroller image.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be\nused to fetch packages from private registries. They are also applied to\nany images pulled for the package, such as a provider's controller image.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.FunctionRevisionSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revision" = mkOption {
          description = "Revision number. Indicates when the revision will be garbage collected\nbased on the parent's RevisionHistoryLimit.";
          type = types.int;
        };
        "runtimeConfigRef" = mkOption {
          description = "RuntimeConfigRef references a RuntimeConfig resource that will be used\nto configure the package runtime.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionRevisionSpecRuntimeConfigRef");
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "tlsClientSecretName" = mkOption {
          description = "TLSClientSecretName is the name of the TLS Secret that stores client\ncertificates of the Provider.";
          type = types.nullOr types.str;
        };
        "tlsServerSecretName" = mkOption {
          description = "TLSServerSecretName is the name of the TLS Secret that stores server\ncertificates of the Provider.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "controllerConfigRef" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "runtimeConfigRef" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
        "tlsClientSecretName" = mkOverride 1002 null;
        "tlsServerSecretName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionSpecControllerConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the ControllerConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1.FunctionRevisionSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionSpecRuntimeConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the RuntimeConfig.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.FunctionRevisionStatusConditions"));
        };
        "endpoint" = mkOption {
          description = "Endpoint is the gRPC endpoint where Crossplane will send\nRunFunctionRequests.";
          type = types.nullOr types.str;
        };
        "foundDependencies" = mkOption {
          description = "Dependency information.";
          type = types.nullOr types.int;
        };
        "installedDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "invalidDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "objectRefs" = mkOption {
          description = "References to objects owned by PackageRevision.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.FunctionRevisionStatusObjectRefs" "name" []);
          apply = attrsToList;
        };
        "permissionRequests" = mkOption {
          description = "PermissionRequests made by this package. The package declares that its\ncontroller needs these permissions to run. The RBAC manager is\nresponsible for granting them.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.FunctionRevisionStatusPermissionRequests"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "endpoint" = mkOverride 1002 null;
        "foundDependencies" = mkOverride 1002 null;
        "installedDependencies" = mkOverride 1002 null;
        "invalidDependencies" = mkOverride 1002 null;
        "objectRefs" = mkOverride 1002 null;
        "permissionRequests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionStatusObjectRefs" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the referenced object.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referenced object.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referenced object.";
          type = types.str;
        };
        "uid" = mkOption {
          description = "UID of the referenced object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "uid" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionRevisionStatusPermissionRequests" = {
      options = {
        "apiGroups" = mkOption {
          description = "APIGroups is the name of the APIGroup that contains the resources.  If multiple API groups are specified, any action requested against one of\nthe enumerated resources in any API group will be allowed. \"\" represents the core API group and \"*\" represents all API groups.";
          type = types.nullOr (types.listOf types.str);
        };
        "nonResourceURLs" = mkOption {
          description = "NonResourceURLs is a set of partial urls that a user should have access to.  *s are allowed, but only as the full, final step in the path\nSince non-resource URLs are not namespaced, this field is only applicable for ClusterRoles referenced from a ClusterRoleBinding.\nRules can either apply to API resources (such as \"pods\" or \"secrets\") or non-resource URL paths (such as \"/api\"),  but not both.";
          type = types.nullOr (types.listOf types.str);
        };
        "resourceNames" = mkOption {
          description = "ResourceNames is an optional white list of names that the rule applies to.  An empty set means that everything is allowed.";
          type = types.nullOr (types.listOf types.str);
        };
        "resources" = mkOption {
          description = "Resources is a list of resources this rule applies to. '*' represents all resources.";
          type = types.nullOr (types.listOf types.str);
        };
        "verbs" = mkOption {
          description = "Verbs is a list of Verbs that apply to ALL the ResourceKinds contained in this rule. '*' represents all verbs.";
          type = types.listOf types.str;
        };
      };

      config = {
        "apiGroups" = mkOverride 1002 null;
        "nonResourceURLs" = mkOverride 1002 null;
        "resourceNames" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "controllerConfigRef" = mkOption {
          description = "ControllerConfigRef references a ControllerConfig resource that will be\nused to configure the packaged controller Deployment.\nDeprecated: Use RuntimeConfigReference instead.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionSpecControllerConfigRef");
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "package" = mkOption {
          description = "Package is the name of the package that is being requested.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be used\nto fetch packages from private registries.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.FunctionSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revisionActivationPolicy" = mkOption {
          description = "RevisionActivationPolicy specifies how the package controller should\nupdate from one revision to the next. Options are Automatic or Manual.\nDefault is Automatic.";
          type = types.nullOr types.str;
        };
        "revisionHistoryLimit" = mkOption {
          description = "RevisionHistoryLimit dictates how the package controller cleans up old\ninactive package revisions.\nDefaults to 1. Can be disabled by explicitly setting to 0.";
          type = types.nullOr types.int;
        };
        "runtimeConfigRef" = mkOption {
          description = "RuntimeConfigRef references a RuntimeConfig resource that will be used\nto configure the package runtime.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.FunctionSpecRuntimeConfigRef");
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "controllerConfigRef" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "revisionActivationPolicy" = mkOverride 1002 null;
        "revisionHistoryLimit" = mkOverride 1002 null;
        "runtimeConfigRef" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionSpecControllerConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the ControllerConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1.FunctionSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionSpecRuntimeConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the RuntimeConfig.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.FunctionStatusConditions"));
        };
        "currentIdentifier" = mkOption {
          description = "CurrentIdentifier is the most recent package source that was used to\nproduce a revision. The package manager uses this field to determine\nwhether to check for package updates for a given source when\npackagePullPolicy is set to IfNotPresent. Manually removing this field\nwill cause the package manager to check that the current revision is\ncorrect for the given package source.";
          type = types.nullOr types.str;
        };
        "currentRevision" = mkOption {
          description = "CurrentRevision is the name of the current package revision. It will\nreflect the most up to date revision, whether it has been activated or\nnot.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "currentIdentifier" = mkOverride 1002 null;
        "currentRevision" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.FunctionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.Provider" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "ProviderSpec specifies details about a request to install a provider to\nCrossplane.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderSpec");
        };
        "status" = mkOption {
          description = "ProviderStatus represents the observed state of a Provider.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevision" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "ProviderRevisionSpec specifies configuration for a ProviderRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderRevisionSpec");
        };
        "status" = mkOption {
          description = "PackageRevisionStatus represents the observed state of a PackageRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderRevisionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "controllerConfigRef" = mkOption {
          description = "ControllerConfigRef references a ControllerConfig resource that will be\nused to configure the packaged controller Deployment.\nDeprecated: Use RuntimeConfigReference instead.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderRevisionSpecControllerConfigRef");
        };
        "desiredState" = mkOption {
          description = "DesiredState of the PackageRevision. Can be either Active or Inactive.";
          type = types.str;
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "image" = mkOption {
          description = "Package image used by install Pod to extract package contents.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package. It is also\napplied to any images pulled for the package, such as a provider's\ncontroller image.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be\nused to fetch packages from private registries. They are also applied to\nany images pulled for the package, such as a provider's controller image.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.ProviderRevisionSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revision" = mkOption {
          description = "Revision number. Indicates when the revision will be garbage collected\nbased on the parent's RevisionHistoryLimit.";
          type = types.int;
        };
        "runtimeConfigRef" = mkOption {
          description = "RuntimeConfigRef references a RuntimeConfig resource that will be used\nto configure the package runtime.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderRevisionSpecRuntimeConfigRef");
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "tlsClientSecretName" = mkOption {
          description = "TLSClientSecretName is the name of the TLS Secret that stores client\ncertificates of the Provider.";
          type = types.nullOr types.str;
        };
        "tlsServerSecretName" = mkOption {
          description = "TLSServerSecretName is the name of the TLS Secret that stores server\ncertificates of the Provider.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "controllerConfigRef" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "runtimeConfigRef" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
        "tlsClientSecretName" = mkOverride 1002 null;
        "tlsServerSecretName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionSpecControllerConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the ControllerConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1.ProviderRevisionSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionSpecRuntimeConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the RuntimeConfig.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.ProviderRevisionStatusConditions"));
        };
        "foundDependencies" = mkOption {
          description = "Dependency information.";
          type = types.nullOr types.int;
        };
        "installedDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "invalidDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "objectRefs" = mkOption {
          description = "References to objects owned by PackageRevision.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.ProviderRevisionStatusObjectRefs" "name" []);
          apply = attrsToList;
        };
        "permissionRequests" = mkOption {
          description = "PermissionRequests made by this package. The package declares that its\ncontroller needs these permissions to run. The RBAC manager is\nresponsible for granting them.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.ProviderRevisionStatusPermissionRequests"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "foundDependencies" = mkOverride 1002 null;
        "installedDependencies" = mkOverride 1002 null;
        "invalidDependencies" = mkOverride 1002 null;
        "objectRefs" = mkOverride 1002 null;
        "permissionRequests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionStatusObjectRefs" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the referenced object.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referenced object.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referenced object.";
          type = types.str;
        };
        "uid" = mkOption {
          description = "UID of the referenced object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "uid" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderRevisionStatusPermissionRequests" = {
      options = {
        "apiGroups" = mkOption {
          description = "APIGroups is the name of the APIGroup that contains the resources.  If multiple API groups are specified, any action requested against one of\nthe enumerated resources in any API group will be allowed. \"\" represents the core API group and \"*\" represents all API groups.";
          type = types.nullOr (types.listOf types.str);
        };
        "nonResourceURLs" = mkOption {
          description = "NonResourceURLs is a set of partial urls that a user should have access to.  *s are allowed, but only as the full, final step in the path\nSince non-resource URLs are not namespaced, this field is only applicable for ClusterRoles referenced from a ClusterRoleBinding.\nRules can either apply to API resources (such as \"pods\" or \"secrets\") or non-resource URL paths (such as \"/api\"),  but not both.";
          type = types.nullOr (types.listOf types.str);
        };
        "resourceNames" = mkOption {
          description = "ResourceNames is an optional white list of names that the rule applies to.  An empty set means that everything is allowed.";
          type = types.nullOr (types.listOf types.str);
        };
        "resources" = mkOption {
          description = "Resources is a list of resources this rule applies to. '*' represents all resources.";
          type = types.nullOr (types.listOf types.str);
        };
        "verbs" = mkOption {
          description = "Verbs is a list of Verbs that apply to ALL the ResourceKinds contained in this rule. '*' represents all verbs.";
          type = types.listOf types.str;
        };
      };

      config = {
        "apiGroups" = mkOverride 1002 null;
        "nonResourceURLs" = mkOverride 1002 null;
        "resourceNames" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "controllerConfigRef" = mkOption {
          description = "ControllerConfigRef references a ControllerConfig resource that will be\nused to configure the packaged controller Deployment.\nDeprecated: Use RuntimeConfigReference instead.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderSpecControllerConfigRef");
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "package" = mkOption {
          description = "Package is the name of the package that is being requested.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be used\nto fetch packages from private registries.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1.ProviderSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revisionActivationPolicy" = mkOption {
          description = "RevisionActivationPolicy specifies how the package controller should\nupdate from one revision to the next. Options are Automatic or Manual.\nDefault is Automatic.";
          type = types.nullOr types.str;
        };
        "revisionHistoryLimit" = mkOption {
          description = "RevisionHistoryLimit dictates how the package controller cleans up old\ninactive package revisions.\nDefaults to 1. Can be disabled by explicitly setting to 0.";
          type = types.nullOr types.int;
        };
        "runtimeConfigRef" = mkOption {
          description = "RuntimeConfigRef references a RuntimeConfig resource that will be used\nto configure the package runtime.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1.ProviderSpecRuntimeConfigRef");
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "controllerConfigRef" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "revisionActivationPolicy" = mkOverride 1002 null;
        "revisionHistoryLimit" = mkOverride 1002 null;
        "runtimeConfigRef" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderSpecControllerConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the ControllerConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1.ProviderSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderSpecRuntimeConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the RuntimeConfig.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1.ProviderStatusConditions"));
        };
        "currentIdentifier" = mkOption {
          description = "CurrentIdentifier is the most recent package source that was used to\nproduce a revision. The package manager uses this field to determine\nwhether to check for package updates for a given source when\npackagePullPolicy is set to IfNotPresent. Manually removing this field\nwill cause the package manager to check that the current revision is\ncorrect for the given package source.";
          type = types.nullOr types.str;
        };
        "currentRevision" = mkOption {
          description = "CurrentRevision is the name of the current package revision. It will\nreflect the most up to date revision, whether it has been activated or\nnot.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "currentIdentifier" = mkOverride 1002 null;
        "currentRevision" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1.ProviderStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfig" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "DeploymentRuntimeConfigSpec specifies the configuration for a packaged controller.\nValues provided will override package manager defaults. Labels and\nannotations are passed to both the controller Deployment and ServiceAccount.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpec" = {
      options = {
        "deploymentTemplate" = mkOption {
          description = "DeploymentTemplate is the template for the Deployment object.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplate");
        };
        "serviceAccountTemplate" = mkOption {
          description = "ServiceAccountTemplate is the template for the ServiceAccount object.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecServiceAccountTemplate");
        };
        "serviceTemplate" = mkOption {
          description = "ServiceTemplate is the template for the Service object.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecServiceTemplate");
        };
      };

      config = {
        "deploymentTemplate" = mkOverride 1002 null;
        "serviceAccountTemplate" = mkOverride 1002 null;
        "serviceTemplate" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplate" = {
      options = {
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec contains the configurable spec fields for the Deployment object.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpec");
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpec" = {
      options = {
        "minReadySeconds" = mkOption {
          description = "Minimum number of seconds for which a newly created pod should be ready\nwithout any of its container crashing, for it to be considered available.\nDefaults to 0 (pod will be considered available as soon as it is ready)";
          type = types.nullOr types.int;
        };
        "paused" = mkOption {
          description = "Indicates that the deployment is paused.";
          type = types.nullOr types.bool;
        };
        "progressDeadlineSeconds" = mkOption {
          description = "The maximum time in seconds for a deployment to make progress before it\nis considered to be failed. The deployment controller will continue to\nprocess failed deployments and a condition with a ProgressDeadlineExceeded\nreason will be surfaced in the deployment status. Note that progress will\nnot be estimated during the time a deployment is paused. Defaults to 600s.";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "Number of desired pods. This is a pointer to distinguish between explicit\nzero and not specified. Defaults to 1.";
          type = types.nullOr types.int;
        };
        "revisionHistoryLimit" = mkOption {
          description = "The number of old ReplicaSets to retain to allow rollback.\nThis is a pointer to distinguish between explicit zero and not specified.\nDefaults to 10.";
          type = types.nullOr types.int;
        };
        "selector" = mkOption {
          description = "Label selector for pods. Existing ReplicaSets whose pods are\nselected by this will be the ones affected by this deployment.\nIt must match the pod template's labels.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecSelector";
        };
        "strategy" = mkOption {
          description = "The deployment strategy to use to replace existing pods with new ones.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecStrategy");
        };
        "template" = mkOption {
          description = "Template describes the pods that will be created.\nThe only allowed template.spec.restartPolicy value is \"Always\".";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplate";
        };
      };

      config = {
        "minReadySeconds" = mkOverride 1002 null;
        "paused" = mkOverride 1002 null;
        "progressDeadlineSeconds" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
        "revisionHistoryLimit" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecStrategy" = {
      options = {
        "rollingUpdate" = mkOption {
          description = "Rolling update config params. Present only if DeploymentStrategyType =\nRollingUpdate.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecStrategyRollingUpdate");
        };
        "type" = mkOption {
          description = "Type of deployment. Can be \"Recreate\" or \"RollingUpdate\". Default is RollingUpdate.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "rollingUpdate" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecStrategyRollingUpdate" = {
      options = {
        "maxSurge" = mkOption {
          description = "The maximum number of pods that can be scheduled above the desired number of\npods.\nValue can be an absolute number (ex: 5) or a percentage of desired pods (ex: 10%).\nThis can not be 0 if MaxUnavailable is 0.\nAbsolute number is calculated from percentage by rounding up.\nDefaults to 25%.\nExample: when this is set to 30%, the new ReplicaSet can be scaled up immediately when\nthe rolling update starts, such that the total number of old and new pods do not exceed\n130% of desired pods. Once old pods have been killed,\nnew ReplicaSet can be scaled up further, ensuring that total number of pods running\nat any time during the update is at most 130% of desired pods.";
          type = types.nullOr (types.either types.int types.str);
        };
        "maxUnavailable" = mkOption {
          description = "The maximum number of pods that can be unavailable during the update.\nValue can be an absolute number (ex: 5) or a percentage of desired pods (ex: 10%).\nAbsolute number is calculated from percentage by rounding down.\nThis can not be 0 if MaxSurge is 0.\nDefaults to 25%.\nExample: when this is set to 30%, the old ReplicaSet can be scaled down to 70% of desired pods\nimmediately when the rolling update starts. Once new pods are ready, old ReplicaSet\ncan be scaled down further, followed by scaling up the new ReplicaSet, ensuring\nthat the total number of pods available at all times during the update is at\nleast 70% of desired pods.";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "maxSurge" = mkOverride 1002 null;
        "maxUnavailable" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplate" = {
      options = {
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Specification of the desired behavior of the pod.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpec");
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpec" = {
      options = {
        "activeDeadlineSeconds" = mkOption {
          description = "Optional duration in seconds the pod may be active on the node relative to\nStartTime before the system will actively try to mark it failed and kill associated containers.\nValue must be a positive integer.";
          type = types.nullOr types.int;
        };
        "affinity" = mkOption {
          description = "If specified, the pod's scheduling constraints";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinity");
        };
        "automountServiceAccountToken" = mkOption {
          description = "AutomountServiceAccountToken indicates whether a service account token should be automatically mounted.";
          type = types.nullOr types.bool;
        };
        "containers" = mkOption {
          description = "List of containers belonging to the pod.\nContainers cannot currently be added or removed.\nThere must be at least one container in a Pod.\nCannot be updated.";
          type = coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainers" "name" ["name"];
          apply = attrsToList;
        };
        "dnsConfig" = mkOption {
          description = "Specifies the DNS parameters of a pod.\nParameters specified here will be merged to the generated DNS\nconfiguration based on DNSPolicy.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecDnsConfig");
        };
        "dnsPolicy" = mkOption {
          description = "Set DNS policy for the pod.\nDefaults to \"ClusterFirst\".\nValid values are 'ClusterFirstWithHostNet', 'ClusterFirst', 'Default' or 'None'.\nDNS parameters given in DNSConfig will be merged with the policy selected with DNSPolicy.\nTo have DNS options set along with hostNetwork, you have to specify DNS policy\nexplicitly to 'ClusterFirstWithHostNet'.";
          type = types.nullOr types.str;
        };
        "enableServiceLinks" = mkOption {
          description = "EnableServiceLinks indicates whether information about services should be injected into pod's\nenvironment variables, matching the syntax of Docker links.\nOptional: Defaults to true.";
          type = types.nullOr types.bool;
        };
        "ephemeralContainers" = mkOption {
          description = "List of ephemeral containers run in this pod. Ephemeral containers may be run in an existing\npod to perform user-initiated actions such as debugging. This list cannot be specified when\ncreating a pod, and it cannot be modified by updating the pod spec. In order to add an\nephemeral container to an existing pod, use the pod's ephemeralcontainers subresource.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainers" "name" ["name"]);
          apply = attrsToList;
        };
        "hostAliases" = mkOption {
          description = "HostAliases is an optional list of hosts and IPs that will be injected into the pod's hosts\nfile if specified.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecHostAliases"));
        };
        "hostIPC" = mkOption {
          description = "Use the host's ipc namespace.\nOptional: Default to false.";
          type = types.nullOr types.bool;
        };
        "hostNetwork" = mkOption {
          description = "Host networking requested for this pod. Use the host's network namespace.\nIf this option is set, the ports that will be used must be specified.\nDefault to false.";
          type = types.nullOr types.bool;
        };
        "hostPID" = mkOption {
          description = "Use the host's pid namespace.\nOptional: Default to false.";
          type = types.nullOr types.bool;
        };
        "hostUsers" = mkOption {
          description = "Use the host's user namespace.\nOptional: Default to true.\nIf set to true or not present, the pod will be run in the host user namespace, useful\nfor when the pod needs a feature only available to the host user namespace, such as\nloading a kernel module with CAP_SYS_MODULE.\nWhen set to false, a new userns is created for the pod. Setting false is useful for\nmitigating container breakout vulnerabilities even allowing users to run their\ncontainers as root without actually having root privileges on the host.\nThis field is alpha-level and is only honored by servers that enable the UserNamespacesSupport feature.";
          type = types.nullOr types.bool;
        };
        "hostname" = mkOption {
          description = "Specifies the hostname of the Pod\nIf not specified, the pod's hostname will be set to a system-defined value.";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "ImagePullSecrets is an optional list of references to secrets in the same namespace to use for pulling any of the images used by this PodSpec.\nIf specified, these secrets will be passed to individual puller implementations for them to use.\nMore info: https://kubernetes.io/docs/concepts/containers/images#specifying-imagepullsecrets-on-a-pod";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecImagePullSecrets" "name" ["name"]);
          apply = attrsToList;
        };
        "initContainers" = mkOption {
          description = "List of initialization containers belonging to the pod.\nInit containers are executed in order prior to containers being started. If any\ninit container fails, the pod is considered to have failed and is handled according\nto its restartPolicy. The name for an init container or normal container must be\nunique among all containers.\nInit containers may not have Lifecycle actions, Readiness probes, Liveness probes, or Startup probes.\nThe resourceRequirements of an init container are taken into account during scheduling\nby finding the highest request/limit for each resource type, and then using the max of\nof that value or the sum of the normal containers. Limits are applied to init containers\nin a similar fashion.\nInit containers cannot currently be added or removed.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainers" "name" ["name"]);
          apply = attrsToList;
        };
        "nodeName" = mkOption {
          description = "NodeName indicates in which node this pod is scheduled.\nIf empty, this pod is a candidate for scheduling by the scheduler defined in schedulerName.\nOnce this field is set, the kubelet for this node becomes responsible for the lifecycle of this pod.\nThis field should not be used to express a desire for the pod to be scheduled on a specific node.\nhttps://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodename";
          type = types.nullOr types.str;
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector is a selector which must be true for the pod to fit on a node.\nSelector which must match a node's labels for the pod to be scheduled on that node.\nMore info: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "os" = mkOption {
          description = "Specifies the OS of the containers in the pod.\nSome pod and container fields are restricted if this is set.\n\nIf the OS field is set to linux, the following fields must be unset:\n-securityContext.windowsOptions\n\nIf the OS field is set to windows, following fields must be unset:\n- spec.hostPID\n- spec.hostIPC\n- spec.hostUsers\n- spec.securityContext.appArmorProfile\n- spec.securityContext.seLinuxOptions\n- spec.securityContext.seccompProfile\n- spec.securityContext.fsGroup\n- spec.securityContext.fsGroupChangePolicy\n- spec.securityContext.sysctls\n- spec.shareProcessNamespace\n- spec.securityContext.runAsUser\n- spec.securityContext.runAsGroup\n- spec.securityContext.supplementalGroups\n- spec.securityContext.supplementalGroupsPolicy\n- spec.containers[*].securityContext.appArmorProfile\n- spec.containers[*].securityContext.seLinuxOptions\n- spec.containers[*].securityContext.seccompProfile\n- spec.containers[*].securityContext.capabilities\n- spec.containers[*].securityContext.readOnlyRootFilesystem\n- spec.containers[*].securityContext.privileged\n- spec.containers[*].securityContext.allowPrivilegeEscalation\n- spec.containers[*].securityContext.procMount\n- spec.containers[*].securityContext.runAsUser\n- spec.containers[*].securityContext.runAsGroup";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecOs");
        };
        "overhead" = mkOption {
          description = "Overhead represents the resource overhead associated with running a pod for a given RuntimeClass.\nThis field will be autopopulated at admission time by the RuntimeClass admission controller. If\nthe RuntimeClass admission controller is enabled, overhead must not be set in Pod create requests.\nThe RuntimeClass admission controller will reject Pod create requests which have the overhead already\nset. If RuntimeClass is configured and selected in the PodSpec, Overhead will be set to the value\ndefined in the corresponding RuntimeClass, otherwise it will remain unset and treated as zero.\nMore info: https://git.k8s.io/enhancements/keps/sig-node/688-pod-overhead/README.md";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "preemptionPolicy" = mkOption {
          description = "PreemptionPolicy is the Policy for preempting pods with lower priority.\nOne of Never, PreemptLowerPriority.\nDefaults to PreemptLowerPriority if unset.";
          type = types.nullOr types.str;
        };
        "priority" = mkOption {
          description = "The priority value. Various system components use this field to find the\npriority of the pod. When Priority Admission Controller is enabled, it\nprevents users from setting this field. The admission controller populates\nthis field from PriorityClassName.\nThe higher the value, the higher the priority.";
          type = types.nullOr types.int;
        };
        "priorityClassName" = mkOption {
          description = "If specified, indicates the pod's priority. \"system-node-critical\" and\n\"system-cluster-critical\" are two special keywords which indicate the\nhighest priorities with the former being the highest priority. Any other\nname must be defined by creating a PriorityClass object with that name.\nIf not specified, the pod priority will be default or zero if there is no\ndefault.";
          type = types.nullOr types.str;
        };
        "readinessGates" = mkOption {
          description = "If specified, all readiness gates will be evaluated for pod readiness.\nA pod is ready when all its containers are ready AND\nall conditions specified in the readiness gates have status equal to \"True\"\nMore info: https://git.k8s.io/enhancements/keps/sig-network/580-pod-readiness-gates";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecReadinessGates"));
        };
        "resourceClaims" = mkOption {
          description = "ResourceClaims defines which ResourceClaims must be allocated\nand reserved before the Pod is allowed to start. The resources\nwill be made available to those containers which consume them\nby name.\n\nThis is an alpha field and requires enabling the\nDynamicResourceAllocation feature gate.\n\nThis field is immutable.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecResourceClaims" "name" ["name"]);
          apply = attrsToList;
        };
        "restartPolicy" = mkOption {
          description = "Restart policy for all containers within the pod.\nOne of Always, OnFailure, Never. In some contexts, only a subset of those values may be permitted.\nDefault to Always.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy";
          type = types.nullOr types.str;
        };
        "runtimeClassName" = mkOption {
          description = "RuntimeClassName refers to a RuntimeClass object in the node.k8s.io group, which should be used\nto run this pod.  If no RuntimeClass resource matches the named class, the pod will not be run.\nIf unset or empty, the \"legacy\" RuntimeClass will be used, which is an implicit class with an\nempty definition that uses the default runtime handler.\nMore info: https://git.k8s.io/enhancements/keps/sig-node/585-runtime-class";
          type = types.nullOr types.str;
        };
        "schedulerName" = mkOption {
          description = "If specified, the pod will be dispatched by specified scheduler.\nIf not specified, the pod will be dispatched by default scheduler.";
          type = types.nullOr types.str;
        };
        "schedulingGates" = mkOption {
          description = "SchedulingGates is an opaque list of values that if specified will block scheduling the pod.\nIf schedulingGates is not empty, the pod will stay in the SchedulingGated state and the\nscheduler will not attempt to schedule the pod.\n\nSchedulingGates can only be set at pod creation time, and be removed only afterwards.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSchedulingGates" "name" ["name"]);
          apply = attrsToList;
        };
        "securityContext" = mkOption {
          description = "SecurityContext holds pod-level security attributes and common container settings.\nOptional: Defaults to empty.  See type description for default values of each field.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContext");
        };
        "serviceAccount" = mkOption {
          description = "DeprecatedServiceAccount is a deprecated alias for ServiceAccountName.\nDeprecated: Use serviceAccountName instead.";
          type = types.nullOr types.str;
        };
        "serviceAccountName" = mkOption {
          description = "ServiceAccountName is the name of the ServiceAccount to use to run this pod.\nMore info: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/";
          type = types.nullOr types.str;
        };
        "setHostnameAsFQDN" = mkOption {
          description = "If true the pod's hostname will be configured as the pod's FQDN, rather than the leaf name (the default).\nIn Linux containers, this means setting the FQDN in the hostname field of the kernel (the nodename field of struct utsname).\nIn Windows containers, this means setting the registry value of hostname for the registry key HKEY_LOCAL_MACHINE\\\\SYSTEM\\\\CurrentControlSet\\\\Services\\\\Tcpip\\\\Parameters to FQDN.\nIf a pod does not have FQDN, this has no effect.\nDefault to false.";
          type = types.nullOr types.bool;
        };
        "shareProcessNamespace" = mkOption {
          description = "Share a single process namespace between all of the containers in a pod.\nWhen this is set containers will be able to view and signal processes from other containers\nin the same pod, and the first process in each container will not be assigned PID 1.\nHostPID and ShareProcessNamespace cannot both be set.\nOptional: Default to false.";
          type = types.nullOr types.bool;
        };
        "subdomain" = mkOption {
          description = "If specified, the fully qualified Pod hostname will be \"<hostname>.<subdomain>.<pod namespace>.svc.<cluster domain>\".\nIf not specified, the pod will not have a domainname at all.";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully. May be decreased in delete request.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nIf this value is nil, the default grace period will be used instead.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nDefaults to 30 seconds.";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "If specified, the pod's tolerations.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTolerations"));
        };
        "topologySpreadConstraints" = mkOption {
          description = "TopologySpreadConstraints describes how a group of pods ought to spread across topology\ndomains. Scheduler will schedule pods in a way which abides by the constraints.\nAll topologySpreadConstraints are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTopologySpreadConstraints"));
        };
        "volumes" = mkOption {
          description = "List of volumes that can be mounted by containers belonging to the pod.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumes" "name" ["name"]);
          apply = attrsToList;
        };
      };

      config = {
        "activeDeadlineSeconds" = mkOverride 1002 null;
        "affinity" = mkOverride 1002 null;
        "automountServiceAccountToken" = mkOverride 1002 null;
        "dnsConfig" = mkOverride 1002 null;
        "dnsPolicy" = mkOverride 1002 null;
        "enableServiceLinks" = mkOverride 1002 null;
        "ephemeralContainers" = mkOverride 1002 null;
        "hostAliases" = mkOverride 1002 null;
        "hostIPC" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "hostPID" = mkOverride 1002 null;
        "hostUsers" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "nodeName" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "os" = mkOverride 1002 null;
        "overhead" = mkOverride 1002 null;
        "preemptionPolicy" = mkOverride 1002 null;
        "priority" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "readinessGates" = mkOverride 1002 null;
        "resourceClaims" = mkOverride 1002 null;
        "restartPolicy" = mkOverride 1002 null;
        "runtimeClassName" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "schedulingGates" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
        "serviceAccount" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "setHostnameAsFQDN" = mkOverride 1002 null;
        "shareProcessNamespace" = mkOverride 1002 null;
        "subdomain" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "topologySpreadConstraints" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinity" = {
      options = {
        "nodeAffinity" = mkOption {
          description = "Describes node affinity scheduling rules for the pod.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "Describes pod affinity scheduling rules (e.g. co-locate this pod in the same node, zone, etc. as some other pod(s)).";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "Describes pod anti-affinity scheduling rules (e.g. avoid putting this pod in the same node, zone, etc. as some other pod(s)).";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinity");
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinity" = {
      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "The scheduler will prefer to schedule pods to nodes that satisfy\nthe affinity expressions specified by this field, but it may choose\na node that violates one or more of the expressions. The node that is\nmost preferred is the one with the greatest sum of weights, i.e.\nfor each node that meets all of the scheduling requirements (resource\nrequest, requiredDuringScheduling affinity expressions, etc.),\ncompute a sum by iterating through the elements of this field and adding\n\"weight\" to the sum if the node matches the corresponding matchExpressions; the\nnode(s) with the highest sum are the most preferred.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"));
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "If the affinity requirements specified by this field are not met at\nscheduling time, the pod will not be scheduled onto the node.\nIf the affinity requirements specified by this field cease to be met\nat some point during pod execution (e.g. due to an update), the system\nmay or may not try to eventually evict the pod from its node.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution");
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" = {
      options = {
        "preference" = mkOption {
          description = "A node selector term, associated with the corresponding weight.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
        };
        "weight" = mkOption {
          description = "Weight associated with matching the corresponding nodeSelectorTerm, in the range 1-100.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" = {
      options = {
        "matchExpressions" = mkOption {
          description = "A list of node selector requirements by node's labels.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"));
        };
        "matchFields" = mkOption {
          description = "A list of node selector requirements by node's fields.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"));
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchFields" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "The label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
          type = types.str;
        };
        "values" = mkOption {
          description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" = {
      options = {
        "key" = mkOption {
          description = "The label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
          type = types.str;
        };
        "values" = mkOption {
          description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" = {
      options = {
        "nodeSelectorTerms" = mkOption {
          description = "Required. A list of node selector terms. The terms are ORed.";
          type = types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms");
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" = {
      options = {
        "matchExpressions" = mkOption {
          description = "A list of node selector requirements by node's labels.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"));
        };
        "matchFields" = mkOption {
          description = "A list of node selector requirements by node's fields.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"));
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchFields" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "The label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
          type = types.str;
        };
        "values" = mkOption {
          description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" = {
      options = {
        "key" = mkOption {
          description = "The label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
          type = types.str;
        };
        "values" = mkOption {
          description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinity" = {
      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "The scheduler will prefer to schedule pods to nodes that satisfy\nthe affinity expressions specified by this field, but it may choose\na node that violates one or more of the expressions. The node that is\nmost preferred is the one with the greatest sum of weights, i.e.\nfor each node that meets all of the scheduling requirements (resource\nrequest, requiredDuringScheduling affinity expressions, etc.),\ncompute a sum by iterating through the elements of this field and adding\n\"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the\nnode(s) with the highest sum are the most preferred.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"));
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "If the affinity requirements specified by this field are not met at\nscheduling time, the pod will not be scheduled onto the node.\nIf the affinity requirements specified by this field cease to be met\nat some point during pod execution (e.g. due to a pod label update), the\nsystem may or may not try to eventually evict the pod from its node.\nWhen there are multiple elements, the lists of nodes corresponding to each\npodAffinityTerm are intersected, i.e. all terms must be satisfied.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"));
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" = {
      options = {
        "podAffinityTerm" = mkOption {
          description = "Required. A pod affinity term, associated with the corresponding weight.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
        };
        "weight" = mkOption {
          description = "weight associated with matching the corresponding podAffinityTerm,\nin the range 1-100.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" = {
      options = {
        "labelSelector" = mkOption {
          description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector");
        };
        "matchLabelKeys" = mkOption {
          description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "mismatchLabelKeys" = mkOption {
          description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "namespaceSelector" = mkOption {
          description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector");
        };
        "namespaces" = mkOption {
          description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
          type = types.nullOr (types.listOf types.str);
        };
        "topologyKey" = mkOption {
          description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
          type = types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "matchLabelKeys" = mkOverride 1002 null;
        "mismatchLabelKeys" = mkOverride 1002 null;
        "namespaceSelector" = mkOverride 1002 null;
        "namespaces" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" = {
      options = {
        "labelSelector" = mkOption {
          description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector");
        };
        "matchLabelKeys" = mkOption {
          description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "mismatchLabelKeys" = mkOption {
          description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "namespaceSelector" = mkOption {
          description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector");
        };
        "namespaces" = mkOption {
          description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
          type = types.nullOr (types.listOf types.str);
        };
        "topologyKey" = mkOption {
          description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
          type = types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "matchLabelKeys" = mkOverride 1002 null;
        "mismatchLabelKeys" = mkOverride 1002 null;
        "namespaceSelector" = mkOverride 1002 null;
        "namespaces" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinity" = {
      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "The scheduler will prefer to schedule pods to nodes that satisfy\nthe anti-affinity expressions specified by this field, but it may choose\na node that violates one or more of the expressions. The node that is\nmost preferred is the one with the greatest sum of weights, i.e.\nfor each node that meets all of the scheduling requirements (resource\nrequest, requiredDuringScheduling anti-affinity expressions, etc.),\ncompute a sum by iterating through the elements of this field and adding\n\"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the\nnode(s) with the highest sum are the most preferred.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"));
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "If the anti-affinity requirements specified by this field are not met at\nscheduling time, the pod will not be scheduled onto the node.\nIf the anti-affinity requirements specified by this field cease to be met\nat some point during pod execution (e.g. due to a pod label update), the\nsystem may or may not try to eventually evict the pod from its node.\nWhen there are multiple elements, the lists of nodes corresponding to each\npodAffinityTerm are intersected, i.e. all terms must be satisfied.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"));
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" = {
      options = {
        "podAffinityTerm" = mkOption {
          description = "Required. A pod affinity term, associated with the corresponding weight.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
        };
        "weight" = mkOption {
          description = "weight associated with matching the corresponding podAffinityTerm,\nin the range 1-100.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" = {
      options = {
        "labelSelector" = mkOption {
          description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector");
        };
        "matchLabelKeys" = mkOption {
          description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "mismatchLabelKeys" = mkOption {
          description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "namespaceSelector" = mkOption {
          description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector");
        };
        "namespaces" = mkOption {
          description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
          type = types.nullOr (types.listOf types.str);
        };
        "topologyKey" = mkOption {
          description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
          type = types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "matchLabelKeys" = mkOverride 1002 null;
        "mismatchLabelKeys" = mkOverride 1002 null;
        "namespaceSelector" = mkOverride 1002 null;
        "namespaces" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" = {
      options = {
        "labelSelector" = mkOption {
          description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector");
        };
        "matchLabelKeys" = mkOption {
          description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "mismatchLabelKeys" = mkOption {
          description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "namespaceSelector" = mkOption {
          description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector");
        };
        "namespaces" = mkOption {
          description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
          type = types.nullOr (types.listOf types.str);
        };
        "topologyKey" = mkOption {
          description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
          type = types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "matchLabelKeys" = mkOverride 1002 null;
        "mismatchLabelKeys" = mkOverride 1002 null;
        "namespaceSelector" = mkOverride 1002 null;
        "namespaces" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainers" = {
      options = {
        "args" = mkOption {
          description = "Arguments to the entrypoint.\nThe container image's CMD is used if this is not provided.\nVariable references $(VAR_NAME) are expanded using the container's environment. If a variable\ncannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless\nof whether the variable exists or not. Cannot be updated.\nMore info: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#running-a-command-in-a-shell";
          type = types.nullOr (types.listOf types.str);
        };
        "command" = mkOption {
          description = "Entrypoint array. Not executed within a shell.\nThe container image's ENTRYPOINT is used if this is not provided.\nVariable references $(VAR_NAME) are expanded using the container's environment. If a variable\ncannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless\nof whether the variable exists or not. Cannot be updated.\nMore info: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#running-a-command-in-a-shell";
          type = types.nullOr (types.listOf types.str);
        };
        "env" = mkOption {
          description = "List of environment variables to set in the container.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnv" "name" ["name"]);
          apply = attrsToList;
        };
        "envFrom" = mkOption {
          description = "List of sources to populate environment variables in the container.\nThe keys defined within a source must be a C_IDENTIFIER. All invalid keys\nwill be reported as an event when the container is starting. When a key exists in multiple\nsources, the value associated with the last source will take precedence.\nValues defined by an Env with a duplicate key will take precedence.\nCannot be updated.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvFrom"));
        };
        "image" = mkOption {
          description = "Container image name.\nMore info: https://kubernetes.io/docs/concepts/containers/images\nThis field is optional to allow higher level config management to default or override\ncontainer images in workload controllers like Deployments and StatefulSets.";
          type = types.nullOr types.str;
        };
        "imagePullPolicy" = mkOption {
          description = "Image pull policy.\nOne of Always, Never, IfNotPresent.\nDefaults to Always if :latest tag is specified, or IfNotPresent otherwise.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/containers/images#updating-images";
          type = types.nullOr types.str;
        };
        "lifecycle" = mkOption {
          description = "Actions that the management system should take in response to container lifecycle events.\nCannot be updated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecycle");
        };
        "livenessProbe" = mkOption {
          description = "Periodic probe of container liveness.\nContainer will be restarted if the probe fails.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbe");
        };
        "name" = mkOption {
          description = "Name of the container specified as a DNS_LABEL.\nEach container in a pod must have a unique name (DNS_LABEL).\nCannot be updated.";
          type = types.str;
        };
        "ports" = mkOption {
          description = "List of ports to expose from the container. Not specifying a port here\nDOES NOT prevent that port from being exposed. Any port which is\nlistening on the default \"0.0.0.0\" address inside a container will be\naccessible from the network.\nModifying this array with strategic merge patch may corrupt the data.\nFor more information See https://github.com/kubernetes/kubernetes/issues/108255.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersPorts" "name" ["containerPort" "protocol"]);
          apply = attrsToList;
        };
        "readinessProbe" = mkOption {
          description = "Periodic probe of container service readiness.\nContainer will be removed from service endpoints if the probe fails.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbe");
        };
        "resizePolicy" = mkOption {
          description = "Resources resize policy for the container.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersResizePolicy"));
        };
        "resources" = mkOption {
          description = "Compute Resources required by this container.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersResources");
        };
        "restartPolicy" = mkOption {
          description = "RestartPolicy defines the restart behavior of individual containers in a pod.\nThis field may only be set for init containers, and the only allowed value is \"Always\".\nFor non-init containers or when this field is not specified,\nthe restart behavior is defined by the Pod's restart policy and the container type.\nSetting the RestartPolicy as \"Always\" for the init container will have the following effect:\nthis init container will be continually restarted on\nexit until all regular containers have terminated. Once all regular\ncontainers have completed, all init containers with restartPolicy \"Always\"\nwill be shut down. This lifecycle differs from normal init containers and\nis often referred to as a \"sidecar\" container. Although this init\ncontainer still starts in the init container sequence, it does not wait\nfor the container to complete before proceeding to the next init\ncontainer. Instead, the next init container starts immediately after this\ninit container is started, or after any startupProbe has successfully\ncompleted.";
          type = types.nullOr types.str;
        };
        "securityContext" = mkOption {
          description = "SecurityContext defines the security options the container should be run with.\nIf set, the fields of SecurityContext override the equivalent fields of PodSecurityContext.\nMore info: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContext");
        };
        "startupProbe" = mkOption {
          description = "StartupProbe indicates that the Pod has successfully initialized.\nIf specified, no other probes are executed until this completes successfully.\nIf this probe fails, the Pod will be restarted, just as if the livenessProbe failed.\nThis can be used to provide different probe parameters at the beginning of a Pod's lifecycle,\nwhen it might take a long time to load data or warm a cache, than during steady-state operation.\nThis cannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbe");
        };
        "stdin" = mkOption {
          description = "Whether this container should allocate a buffer for stdin in the container runtime. If this\nis not set, reads from stdin in the container will always result in EOF.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "stdinOnce" = mkOption {
          description = "Whether the container runtime should close the stdin channel after it has been opened by\na single attach. When stdin is true the stdin stream will remain open across multiple attach\nsessions. If stdinOnce is set to true, stdin is opened on container start, is empty until the\nfirst client attaches to stdin, and then remains open and accepts data until the client disconnects,\nat which time stdin is closed and remains closed until the container is restarted. If this\nflag is false, a container processes that reads from stdin will never receive an EOF.\nDefault is false";
          type = types.nullOr types.bool;
        };
        "terminationMessagePath" = mkOption {
          description = "Optional: Path at which the file to which the container's termination message\nwill be written is mounted into the container's filesystem.\nMessage written is intended to be brief final status, such as an assertion failure message.\nWill be truncated by the node if greater than 4096 bytes. The total message length across\nall containers will be limited to 12kb.\nDefaults to /dev/termination-log.\nCannot be updated.";
          type = types.nullOr types.str;
        };
        "terminationMessagePolicy" = mkOption {
          description = "Indicate how the termination message should be populated. File will use the contents of\nterminationMessagePath to populate the container status message on both success and failure.\nFallbackToLogsOnError will use the last chunk of container log output if the termination\nmessage file is empty and the container exited with an error.\nThe log output is limited to 2048 bytes or 80 lines, whichever is smaller.\nDefaults to File.\nCannot be updated.";
          type = types.nullOr types.str;
        };
        "tty" = mkOption {
          description = "Whether this container should allocate a TTY for itself, also requires 'stdin' to be true.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "volumeDevices" = mkOption {
          description = "volumeDevices is the list of block devices to be used by the container.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersVolumeDevices" "name" ["devicePath"]);
          apply = attrsToList;
        };
        "volumeMounts" = mkOption {
          description = "Pod volumes to mount into the container's filesystem.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersVolumeMounts" "name" ["mountPath"]);
          apply = attrsToList;
        };
        "workingDir" = mkOption {
          description = "Container's working directory.\nIf not specified, the container runtime's default will be used, which\nmight be configured in the container image.\nCannot be updated.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "args" = mkOverride 1002 null;
        "command" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "envFrom" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "lifecycle" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "resizePolicy" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "restartPolicy" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
        "startupProbe" = mkOverride 1002 null;
        "stdin" = mkOverride 1002 null;
        "stdinOnce" = mkOverride 1002 null;
        "terminationMessagePath" = mkOverride 1002 null;
        "terminationMessagePolicy" = mkOverride 1002 null;
        "tty" = mkOverride 1002 null;
        "volumeDevices" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "workingDir" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnv" = {
      options = {
        "name" = mkOption {
          description = "Name of the environment variable. Must be a C_IDENTIFIER.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Variable references $(VAR_NAME) are expanded\nusing the previously defined environment variables in the container and\nany service environment variables. If a variable cannot be resolved,\nthe reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e.\n\"$$(VAR_NAME)\" will produce the string literal \"$(VAR_NAME)\".\nEscaped references will never be expanded, regardless of whether the variable\nexists or not.\nDefaults to \"\".";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "Source for the environment variable's value. Cannot be used if value is not empty.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvFrom" = {
      options = {
        "configMapRef" = mkOption {
          description = "The ConfigMap to select from";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvFromConfigMapRef");
        };
        "prefix" = mkOption {
          description = "An optional identifier to prepend to each key in the ConfigMap. Must be a C_IDENTIFIER.";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "The Secret to select from";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvFromSecretRef");
        };
      };

      config = {
        "configMapRef" = mkOverride 1002 null;
        "prefix" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvFromConfigMapRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the ConfigMap must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvFromSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the Secret must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFrom" = {
      options = {
        "configMapKeyRef" = mkOption {
          description = "Selects a key of a ConfigMap.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromConfigMapKeyRef");
        };
        "fieldRef" = mkOption {
          description = "Selects a field of the pod: supports metadata.name, metadata.namespace, `metadata.labels['<KEY>']`, `metadata.annotations['<KEY>']`,\nspec.nodeName, spec.serviceAccountName, status.hostIP, status.podIP, status.podIPs.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromFieldRef");
        };
        "resourceFieldRef" = mkOption {
          description = "Selects a resource of the container: only resources limits and requests\n(limits.cpu, limits.memory, limits.ephemeral-storage, requests.cpu, requests.memory and requests.ephemeral-storage) are currently supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromResourceFieldRef");
        };
        "secretKeyRef" = mkOption {
          description = "Selects a key of a secret in the pod's namespace";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromSecretKeyRef");
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromConfigMapKeyRef" = {
      options = {
        "key" = mkOption {
          description = "The key to select.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the ConfigMap or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromFieldRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "Version of the schema the FieldPath is written in terms of, defaults to \"v1\".";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "Path of the field to select in the specified API version.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromResourceFieldRef" = {
      options = {
        "containerName" = mkOption {
          description = "Container name: required for volumes, optional for env vars";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "Specifies the output format of the exposed resources, defaults to \"1\"";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "Required: resource to select";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersEnvValueFromSecretKeyRef" = {
      options = {
        "key" = mkOption {
          description = "The key of the secret to select from.  Must be a valid secret key.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the Secret or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecycle" = {
      options = {
        "postStart" = mkOption {
          description = "PostStart is called immediately after a container is created. If the handler fails,\nthe container is terminated and restarted according to its restart policy.\nOther management of the container blocks until the hook completes.\nMore info: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#container-hooks";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStart");
        };
        "preStop" = mkOption {
          description = "PreStop is called immediately before a container is terminated due to an\nAPI request or management event such as liveness/startup probe failure,\npreemption, resource contention, etc. The handler is not called if the\ncontainer crashes or exits. The Pod's termination grace period countdown begins before the\nPreStop hook is executed. Regardless of the outcome of the handler, the\ncontainer will eventually terminate within the Pod's termination grace\nperiod (unless delayed by finalizers). Other management of the container blocks until the hook completes\nor until the termination grace period is reached.\nMore info: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#container-hooks";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStop");
        };
      };

      config = {
        "postStart" = mkOverride 1002 null;
        "preStop" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStart" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartExec");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartHttpGet");
        };
        "sleep" = mkOption {
          description = "Sleep represents the duration that the container should sleep before being terminated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartSleep");
        };
        "tcpSocket" = mkOption {
          description = "Deprecated. TCPSocket is NOT supported as a LifecycleHandler and kept\nfor the backward compatibility. There are no validation of this field and\nlifecycle hooks will fail in runtime when tcp handler is specified.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartTcpSocket");
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "sleep" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartSleep" = {
      options = {
        "seconds" = mkOption {
          description = "Seconds is the number of seconds to sleep.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePostStartTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStop" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopExec");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopHttpGet");
        };
        "sleep" = mkOption {
          description = "Sleep represents the duration that the container should sleep before being terminated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopSleep");
        };
        "tcpSocket" = mkOption {
          description = "Deprecated. TCPSocket is NOT supported as a LifecycleHandler and kept\nfor the backward compatibility. There are no validation of this field and\nlifecycle hooks will fail in runtime when tcp handler is specified.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopTcpSocket");
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "sleep" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopSleep" = {
      options = {
        "seconds" = mkOption {
          description = "Seconds is the number of seconds to sleep.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLifecyclePreStopTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersLivenessProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersPorts" = {
      options = {
        "containerPort" = mkOption {
          description = "Number of port to expose on the pod's IP address.\nThis must be a valid port number, 0 < x < 65536.";
          type = types.int;
        };
        "hostIP" = mkOption {
          description = "What host IP to bind the external port to.";
          type = types.nullOr types.str;
        };
        "hostPort" = mkOption {
          description = "Number of port to expose on the host.\nIf specified, this must be a valid port number, 0 < x < 65536.\nIf HostNetwork is specified, this must match ContainerPort.\nMost containers do not need this.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "If specified, this must be an IANA_SVC_NAME and unique within the pod. Each\nnamed port in a pod must have a unique name. Name for the port that can be\nreferred to by services.";
          type = types.nullOr types.str;
        };
        "protocol" = mkOption {
          description = "Protocol for port. Must be UDP, TCP, or SCTP.\nDefaults to \"TCP\".";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hostIP" = mkOverride 1002 null;
        "hostPort" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersReadinessProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersResizePolicy" = {
      options = {
        "resourceName" = mkOption {
          description = "Name of the resource to which this resource resize policy applies.\nSupported values: cpu, memory.";
          type = types.str;
        };
        "restartPolicy" = mkOption {
          description = "Restart policy to apply when specified resource is resized.\nIf not specified, it defaults to NotRequired.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersResources" = {
      options = {
        "claims" = mkOption {
          description = "Claims lists the names of resources, defined in spec.resourceClaims,\nthat are used by this container.\n\nThis is an alpha field and requires enabling the\nDynamicResourceAllocation feature gate.\n\nThis field is immutable. It can only be set for containers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersResourcesClaims" "name" ["name"]);
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "Limits describes the maximum amount of compute resources allowed.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "Requests describes the minimum amount of compute resources required.\nIf Requests is omitted for a container, it defaults to Limits if that is explicitly specified,\notherwise to an implementation-defined value. Requests cannot exceed Limits.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersResourcesClaims" = {
      options = {
        "name" = mkOption {
          description = "Name must match the name of one entry in pod.spec.resourceClaims of\nthe Pod where this field is used. It makes that resource available\ninside a container.";
          type = types.str;
        };
        "request" = mkOption {
          description = "Request is the name chosen for a request in the referenced claim.\nIf empty, everything from the claim is made available, otherwise\nonly the result of this request.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContext" = {
      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "AllowPrivilegeEscalation controls whether a process can gain more\nprivileges than its parent process. This bool directly controls if\nthe no_new_privs flag will be set on the container process.\nAllowPrivilegeEscalation is true always when the container is:\n1) run as Privileged\n2) has CAP_SYS_ADMIN\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by this container. If set, this profile\noverrides the pod's appArmorProfile.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextAppArmorProfile");
        };
        "capabilities" = mkOption {
          description = "The capabilities to add/drop when running containers.\nDefaults to the default set of capabilities granted by the container runtime.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextCapabilities");
        };
        "privileged" = mkOption {
          description = "Run container in privileged mode.\nProcesses in privileged containers are essentially equivalent to root on the host.\nDefaults to false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "procMount denotes the type of proc mount to use for the containers.\nThe default value is Default which uses the container runtime defaults for\nreadonly paths and masked paths.\nThis requires the ProcMountType feature flag to be enabled.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "Whether this container has a read-only root filesystem.\nDefault is false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to the container.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextSeLinuxOptions");
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by this container. If seccomp options are\nprovided at both the pod & container level, the container options\noverride the pod options.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextSeccompProfile");
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options from the PodSecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextWindowsOptions");
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextAppArmorProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextCapabilities" = {
      options = {
        "add" = mkOption {
          description = "Added capabilities";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "Removed capabilities";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextSeLinuxOptions" = {
      options = {
        "level" = mkOption {
          description = "Level is SELinux level label that applies to the container.";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "Role is a SELinux role label that applies to the container.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type is a SELinux type label that applies to the container.";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "User is a SELinux user label that applies to the container.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextSeccompProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersSecurityContextWindowsOptions" = {
      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersStartupProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersVolumeDevices" = {
      options = {
        "devicePath" = mkOption {
          description = "devicePath is the path inside of the container that the device will be mapped to.";
          type = types.str;
        };
        "name" = mkOption {
          description = "name must match the name of a persistentVolumeClaim in the pod";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecContainersVolumeMounts" = {
      options = {
        "mountPath" = mkOption {
          description = "Path within the container at which the volume should be mounted.  Must\nnot contain ':'.";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "mountPropagation determines how mounts are propagated from the host\nto container and the other way around.\nWhen not set, MountPropagationNone is used.\nThis field is beta in 1.10.\nWhen RecursiveReadOnly is set to IfPossible or to Enabled, MountPropagation must be None or unspecified\n(which defaults to None).";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "This must match the Name of a Volume.";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "Mounted read-only if true, read-write otherwise (false or unspecified).\nDefaults to false.";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "RecursiveReadOnly specifies whether read-only mounts should be handled\nrecursively.\n\nIf ReadOnly is false, this field has no meaning and must be unspecified.\n\nIf ReadOnly is true, and this field is set to Disabled, the mount is not made\nrecursively read-only.  If this field is set to IfPossible, the mount is made\nrecursively read-only, if it is supported by the container runtime.  If this\nfield is set to Enabled, the mount is made recursively read-only if it is\nsupported by the container runtime, otherwise the pod will not be started and\nan error will be generated to indicate the reason.\n\nIf this field is set to IfPossible or Enabled, MountPropagation must be set to\nNone (or be unspecified, which defaults to None).\n\nIf this field is not specified, it is treated as an equivalent of Disabled.";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "Path within the volume from which the container's volume should be mounted.\nDefaults to \"\" (volume's root).";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "Expanded path within the volume from which the container's volume should be mounted.\nBehaves similarly to SubPath but environment variable references $(VAR_NAME) are expanded using the container's environment.\nDefaults to \"\" (volume's root).\nSubPathExpr and SubPath are mutually exclusive.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecDnsConfig" = {
      options = {
        "nameservers" = mkOption {
          description = "A list of DNS name server IP addresses.\nThis will be appended to the base nameservers generated from DNSPolicy.\nDuplicated nameservers will be removed.";
          type = types.nullOr (types.listOf types.str);
        };
        "options" = mkOption {
          description = "A list of DNS resolver options.\nThis will be merged with the base options generated from DNSPolicy.\nDuplicated entries will be removed. Resolution options given in Options\nwill override those that appear in the base DNSPolicy.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecDnsConfigOptions" "name" []);
          apply = attrsToList;
        };
        "searches" = mkOption {
          description = "A list of DNS search domains for host-name lookup.\nThis will be appended to the base search paths generated from DNSPolicy.\nDuplicated search paths will be removed.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "nameservers" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "searches" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecDnsConfigOptions" = {
      options = {
        "name" = mkOption {
          description = "Required.";
          type = types.nullOr types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainers" = {
      options = {
        "args" = mkOption {
          description = "Arguments to the entrypoint.\nThe image's CMD is used if this is not provided.\nVariable references $(VAR_NAME) are expanded using the container's environment. If a variable\ncannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless\nof whether the variable exists or not. Cannot be updated.\nMore info: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#running-a-command-in-a-shell";
          type = types.nullOr (types.listOf types.str);
        };
        "command" = mkOption {
          description = "Entrypoint array. Not executed within a shell.\nThe image's ENTRYPOINT is used if this is not provided.\nVariable references $(VAR_NAME) are expanded using the container's environment. If a variable\ncannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless\nof whether the variable exists or not. Cannot be updated.\nMore info: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#running-a-command-in-a-shell";
          type = types.nullOr (types.listOf types.str);
        };
        "env" = mkOption {
          description = "List of environment variables to set in the container.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnv" "name" ["name"]);
          apply = attrsToList;
        };
        "envFrom" = mkOption {
          description = "List of sources to populate environment variables in the container.\nThe keys defined within a source must be a C_IDENTIFIER. All invalid keys\nwill be reported as an event when the container is starting. When a key exists in multiple\nsources, the value associated with the last source will take precedence.\nValues defined by an Env with a duplicate key will take precedence.\nCannot be updated.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvFrom"));
        };
        "image" = mkOption {
          description = "Container image name.\nMore info: https://kubernetes.io/docs/concepts/containers/images";
          type = types.nullOr types.str;
        };
        "imagePullPolicy" = mkOption {
          description = "Image pull policy.\nOne of Always, Never, IfNotPresent.\nDefaults to Always if :latest tag is specified, or IfNotPresent otherwise.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/containers/images#updating-images";
          type = types.nullOr types.str;
        };
        "lifecycle" = mkOption {
          description = "Lifecycle is not allowed for ephemeral containers.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecycle");
        };
        "livenessProbe" = mkOption {
          description = "Probes are not allowed for ephemeral containers.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbe");
        };
        "name" = mkOption {
          description = "Name of the ephemeral container specified as a DNS_LABEL.\nThis name must be unique among all containers, init containers and ephemeral containers.";
          type = types.str;
        };
        "ports" = mkOption {
          description = "Ports are not allowed for ephemeral containers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersPorts" "name" ["containerPort" "protocol"]);
          apply = attrsToList;
        };
        "readinessProbe" = mkOption {
          description = "Probes are not allowed for ephemeral containers.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbe");
        };
        "resizePolicy" = mkOption {
          description = "Resources resize policy for the container.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersResizePolicy"));
        };
        "resources" = mkOption {
          description = "Resources are not allowed for ephemeral containers. Ephemeral containers use spare resources\nalready allocated to the pod.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersResources");
        };
        "restartPolicy" = mkOption {
          description = "Restart policy for the container to manage the restart behavior of each\ncontainer within a pod.\nThis may only be set for init containers. You cannot set this field on\nephemeral containers.";
          type = types.nullOr types.str;
        };
        "securityContext" = mkOption {
          description = "Optional: SecurityContext defines the security options the ephemeral container should be run with.\nIf set, the fields of SecurityContext override the equivalent fields of PodSecurityContext.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContext");
        };
        "startupProbe" = mkOption {
          description = "Probes are not allowed for ephemeral containers.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbe");
        };
        "stdin" = mkOption {
          description = "Whether this container should allocate a buffer for stdin in the container runtime. If this\nis not set, reads from stdin in the container will always result in EOF.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "stdinOnce" = mkOption {
          description = "Whether the container runtime should close the stdin channel after it has been opened by\na single attach. When stdin is true the stdin stream will remain open across multiple attach\nsessions. If stdinOnce is set to true, stdin is opened on container start, is empty until the\nfirst client attaches to stdin, and then remains open and accepts data until the client disconnects,\nat which time stdin is closed and remains closed until the container is restarted. If this\nflag is false, a container processes that reads from stdin will never receive an EOF.\nDefault is false";
          type = types.nullOr types.bool;
        };
        "targetContainerName" = mkOption {
          description = "If set, the name of the container from PodSpec that this ephemeral container targets.\nThe ephemeral container will be run in the namespaces (IPC, PID, etc) of this container.\nIf not set then the ephemeral container uses the namespaces configured in the Pod spec.\n\nThe container runtime must implement support for this feature. If the runtime does not\nsupport namespace targeting then the result of setting this field is undefined.";
          type = types.nullOr types.str;
        };
        "terminationMessagePath" = mkOption {
          description = "Optional: Path at which the file to which the container's termination message\nwill be written is mounted into the container's filesystem.\nMessage written is intended to be brief final status, such as an assertion failure message.\nWill be truncated by the node if greater than 4096 bytes. The total message length across\nall containers will be limited to 12kb.\nDefaults to /dev/termination-log.\nCannot be updated.";
          type = types.nullOr types.str;
        };
        "terminationMessagePolicy" = mkOption {
          description = "Indicate how the termination message should be populated. File will use the contents of\nterminationMessagePath to populate the container status message on both success and failure.\nFallbackToLogsOnError will use the last chunk of container log output if the termination\nmessage file is empty and the container exited with an error.\nThe log output is limited to 2048 bytes or 80 lines, whichever is smaller.\nDefaults to File.\nCannot be updated.";
          type = types.nullOr types.str;
        };
        "tty" = mkOption {
          description = "Whether this container should allocate a TTY for itself, also requires 'stdin' to be true.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "volumeDevices" = mkOption {
          description = "volumeDevices is the list of block devices to be used by the container.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersVolumeDevices" "name" ["devicePath"]);
          apply = attrsToList;
        };
        "volumeMounts" = mkOption {
          description = "Pod volumes to mount into the container's filesystem. Subpath mounts are not allowed for ephemeral containers.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersVolumeMounts" "name" ["mountPath"]);
          apply = attrsToList;
        };
        "workingDir" = mkOption {
          description = "Container's working directory.\nIf not specified, the container runtime's default will be used, which\nmight be configured in the container image.\nCannot be updated.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "args" = mkOverride 1002 null;
        "command" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "envFrom" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "lifecycle" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "resizePolicy" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "restartPolicy" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
        "startupProbe" = mkOverride 1002 null;
        "stdin" = mkOverride 1002 null;
        "stdinOnce" = mkOverride 1002 null;
        "targetContainerName" = mkOverride 1002 null;
        "terminationMessagePath" = mkOverride 1002 null;
        "terminationMessagePolicy" = mkOverride 1002 null;
        "tty" = mkOverride 1002 null;
        "volumeDevices" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "workingDir" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnv" = {
      options = {
        "name" = mkOption {
          description = "Name of the environment variable. Must be a C_IDENTIFIER.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Variable references $(VAR_NAME) are expanded\nusing the previously defined environment variables in the container and\nany service environment variables. If a variable cannot be resolved,\nthe reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e.\n\"$$(VAR_NAME)\" will produce the string literal \"$(VAR_NAME)\".\nEscaped references will never be expanded, regardless of whether the variable\nexists or not.\nDefaults to \"\".";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "Source for the environment variable's value. Cannot be used if value is not empty.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvFrom" = {
      options = {
        "configMapRef" = mkOption {
          description = "The ConfigMap to select from";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvFromConfigMapRef");
        };
        "prefix" = mkOption {
          description = "An optional identifier to prepend to each key in the ConfigMap. Must be a C_IDENTIFIER.";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "The Secret to select from";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvFromSecretRef");
        };
      };

      config = {
        "configMapRef" = mkOverride 1002 null;
        "prefix" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvFromConfigMapRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the ConfigMap must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvFromSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the Secret must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFrom" = {
      options = {
        "configMapKeyRef" = mkOption {
          description = "Selects a key of a ConfigMap.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromConfigMapKeyRef");
        };
        "fieldRef" = mkOption {
          description = "Selects a field of the pod: supports metadata.name, metadata.namespace, `metadata.labels['<KEY>']`, `metadata.annotations['<KEY>']`,\nspec.nodeName, spec.serviceAccountName, status.hostIP, status.podIP, status.podIPs.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromFieldRef");
        };
        "resourceFieldRef" = mkOption {
          description = "Selects a resource of the container: only resources limits and requests\n(limits.cpu, limits.memory, limits.ephemeral-storage, requests.cpu, requests.memory and requests.ephemeral-storage) are currently supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromResourceFieldRef");
        };
        "secretKeyRef" = mkOption {
          description = "Selects a key of a secret in the pod's namespace";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromSecretKeyRef");
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromConfigMapKeyRef" = {
      options = {
        "key" = mkOption {
          description = "The key to select.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the ConfigMap or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromFieldRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "Version of the schema the FieldPath is written in terms of, defaults to \"v1\".";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "Path of the field to select in the specified API version.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromResourceFieldRef" = {
      options = {
        "containerName" = mkOption {
          description = "Container name: required for volumes, optional for env vars";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "Specifies the output format of the exposed resources, defaults to \"1\"";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "Required: resource to select";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersEnvValueFromSecretKeyRef" = {
      options = {
        "key" = mkOption {
          description = "The key of the secret to select from.  Must be a valid secret key.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the Secret or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecycle" = {
      options = {
        "postStart" = mkOption {
          description = "PostStart is called immediately after a container is created. If the handler fails,\nthe container is terminated and restarted according to its restart policy.\nOther management of the container blocks until the hook completes.\nMore info: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#container-hooks";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStart");
        };
        "preStop" = mkOption {
          description = "PreStop is called immediately before a container is terminated due to an\nAPI request or management event such as liveness/startup probe failure,\npreemption, resource contention, etc. The handler is not called if the\ncontainer crashes or exits. The Pod's termination grace period countdown begins before the\nPreStop hook is executed. Regardless of the outcome of the handler, the\ncontainer will eventually terminate within the Pod's termination grace\nperiod (unless delayed by finalizers). Other management of the container blocks until the hook completes\nor until the termination grace period is reached.\nMore info: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#container-hooks";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStop");
        };
      };

      config = {
        "postStart" = mkOverride 1002 null;
        "preStop" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStart" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartExec");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartHttpGet");
        };
        "sleep" = mkOption {
          description = "Sleep represents the duration that the container should sleep before being terminated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartSleep");
        };
        "tcpSocket" = mkOption {
          description = "Deprecated. TCPSocket is NOT supported as a LifecycleHandler and kept\nfor the backward compatibility. There are no validation of this field and\nlifecycle hooks will fail in runtime when tcp handler is specified.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartTcpSocket");
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "sleep" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartSleep" = {
      options = {
        "seconds" = mkOption {
          description = "Seconds is the number of seconds to sleep.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePostStartTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStop" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopExec");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopHttpGet");
        };
        "sleep" = mkOption {
          description = "Sleep represents the duration that the container should sleep before being terminated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopSleep");
        };
        "tcpSocket" = mkOption {
          description = "Deprecated. TCPSocket is NOT supported as a LifecycleHandler and kept\nfor the backward compatibility. There are no validation of this field and\nlifecycle hooks will fail in runtime when tcp handler is specified.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopTcpSocket");
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "sleep" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopSleep" = {
      options = {
        "seconds" = mkOption {
          description = "Seconds is the number of seconds to sleep.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLifecyclePreStopTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersLivenessProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersPorts" = {
      options = {
        "containerPort" = mkOption {
          description = "Number of port to expose on the pod's IP address.\nThis must be a valid port number, 0 < x < 65536.";
          type = types.int;
        };
        "hostIP" = mkOption {
          description = "What host IP to bind the external port to.";
          type = types.nullOr types.str;
        };
        "hostPort" = mkOption {
          description = "Number of port to expose on the host.\nIf specified, this must be a valid port number, 0 < x < 65536.\nIf HostNetwork is specified, this must match ContainerPort.\nMost containers do not need this.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "If specified, this must be an IANA_SVC_NAME and unique within the pod. Each\nnamed port in a pod must have a unique name. Name for the port that can be\nreferred to by services.";
          type = types.nullOr types.str;
        };
        "protocol" = mkOption {
          description = "Protocol for port. Must be UDP, TCP, or SCTP.\nDefaults to \"TCP\".";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hostIP" = mkOverride 1002 null;
        "hostPort" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersReadinessProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersResizePolicy" = {
      options = {
        "resourceName" = mkOption {
          description = "Name of the resource to which this resource resize policy applies.\nSupported values: cpu, memory.";
          type = types.str;
        };
        "restartPolicy" = mkOption {
          description = "Restart policy to apply when specified resource is resized.\nIf not specified, it defaults to NotRequired.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersResources" = {
      options = {
        "claims" = mkOption {
          description = "Claims lists the names of resources, defined in spec.resourceClaims,\nthat are used by this container.\n\nThis is an alpha field and requires enabling the\nDynamicResourceAllocation feature gate.\n\nThis field is immutable. It can only be set for containers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersResourcesClaims" "name" ["name"]);
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "Limits describes the maximum amount of compute resources allowed.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "Requests describes the minimum amount of compute resources required.\nIf Requests is omitted for a container, it defaults to Limits if that is explicitly specified,\notherwise to an implementation-defined value. Requests cannot exceed Limits.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersResourcesClaims" = {
      options = {
        "name" = mkOption {
          description = "Name must match the name of one entry in pod.spec.resourceClaims of\nthe Pod where this field is used. It makes that resource available\ninside a container.";
          type = types.str;
        };
        "request" = mkOption {
          description = "Request is the name chosen for a request in the referenced claim.\nIf empty, everything from the claim is made available, otherwise\nonly the result of this request.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContext" = {
      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "AllowPrivilegeEscalation controls whether a process can gain more\nprivileges than its parent process. This bool directly controls if\nthe no_new_privs flag will be set on the container process.\nAllowPrivilegeEscalation is true always when the container is:\n1) run as Privileged\n2) has CAP_SYS_ADMIN\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by this container. If set, this profile\noverrides the pod's appArmorProfile.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextAppArmorProfile");
        };
        "capabilities" = mkOption {
          description = "The capabilities to add/drop when running containers.\nDefaults to the default set of capabilities granted by the container runtime.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextCapabilities");
        };
        "privileged" = mkOption {
          description = "Run container in privileged mode.\nProcesses in privileged containers are essentially equivalent to root on the host.\nDefaults to false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "procMount denotes the type of proc mount to use for the containers.\nThe default value is Default which uses the container runtime defaults for\nreadonly paths and masked paths.\nThis requires the ProcMountType feature flag to be enabled.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "Whether this container has a read-only root filesystem.\nDefault is false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to the container.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextSeLinuxOptions");
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by this container. If seccomp options are\nprovided at both the pod & container level, the container options\noverride the pod options.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextSeccompProfile");
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options from the PodSecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextWindowsOptions");
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextAppArmorProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextCapabilities" = {
      options = {
        "add" = mkOption {
          description = "Added capabilities";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "Removed capabilities";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextSeLinuxOptions" = {
      options = {
        "level" = mkOption {
          description = "Level is SELinux level label that applies to the container.";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "Role is a SELinux role label that applies to the container.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type is a SELinux type label that applies to the container.";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "User is a SELinux user label that applies to the container.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextSeccompProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersSecurityContextWindowsOptions" = {
      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersStartupProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersVolumeDevices" = {
      options = {
        "devicePath" = mkOption {
          description = "devicePath is the path inside of the container that the device will be mapped to.";
          type = types.str;
        };
        "name" = mkOption {
          description = "name must match the name of a persistentVolumeClaim in the pod";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecEphemeralContainersVolumeMounts" = {
      options = {
        "mountPath" = mkOption {
          description = "Path within the container at which the volume should be mounted.  Must\nnot contain ':'.";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "mountPropagation determines how mounts are propagated from the host\nto container and the other way around.\nWhen not set, MountPropagationNone is used.\nThis field is beta in 1.10.\nWhen RecursiveReadOnly is set to IfPossible or to Enabled, MountPropagation must be None or unspecified\n(which defaults to None).";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "This must match the Name of a Volume.";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "Mounted read-only if true, read-write otherwise (false or unspecified).\nDefaults to false.";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "RecursiveReadOnly specifies whether read-only mounts should be handled\nrecursively.\n\nIf ReadOnly is false, this field has no meaning and must be unspecified.\n\nIf ReadOnly is true, and this field is set to Disabled, the mount is not made\nrecursively read-only.  If this field is set to IfPossible, the mount is made\nrecursively read-only, if it is supported by the container runtime.  If this\nfield is set to Enabled, the mount is made recursively read-only if it is\nsupported by the container runtime, otherwise the pod will not be started and\nan error will be generated to indicate the reason.\n\nIf this field is set to IfPossible or Enabled, MountPropagation must be set to\nNone (or be unspecified, which defaults to None).\n\nIf this field is not specified, it is treated as an equivalent of Disabled.";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "Path within the volume from which the container's volume should be mounted.\nDefaults to \"\" (volume's root).";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "Expanded path within the volume from which the container's volume should be mounted.\nBehaves similarly to SubPath but environment variable references $(VAR_NAME) are expanded using the container's environment.\nDefaults to \"\" (volume's root).\nSubPathExpr and SubPath are mutually exclusive.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecHostAliases" = {
      options = {
        "hostnames" = mkOption {
          description = "Hostnames for the above IP address.";
          type = types.nullOr (types.listOf types.str);
        };
        "ip" = mkOption {
          description = "IP address of the host file entry.";
          type = types.str;
        };
      };

      config = {
        "hostnames" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecImagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainers" = {
      options = {
        "args" = mkOption {
          description = "Arguments to the entrypoint.\nThe container image's CMD is used if this is not provided.\nVariable references $(VAR_NAME) are expanded using the container's environment. If a variable\ncannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless\nof whether the variable exists or not. Cannot be updated.\nMore info: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#running-a-command-in-a-shell";
          type = types.nullOr (types.listOf types.str);
        };
        "command" = mkOption {
          description = "Entrypoint array. Not executed within a shell.\nThe container image's ENTRYPOINT is used if this is not provided.\nVariable references $(VAR_NAME) are expanded using the container's environment. If a variable\ncannot be resolved, the reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never be expanded, regardless\nof whether the variable exists or not. Cannot be updated.\nMore info: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#running-a-command-in-a-shell";
          type = types.nullOr (types.listOf types.str);
        };
        "env" = mkOption {
          description = "List of environment variables to set in the container.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnv" "name" ["name"]);
          apply = attrsToList;
        };
        "envFrom" = mkOption {
          description = "List of sources to populate environment variables in the container.\nThe keys defined within a source must be a C_IDENTIFIER. All invalid keys\nwill be reported as an event when the container is starting. When a key exists in multiple\nsources, the value associated with the last source will take precedence.\nValues defined by an Env with a duplicate key will take precedence.\nCannot be updated.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvFrom"));
        };
        "image" = mkOption {
          description = "Container image name.\nMore info: https://kubernetes.io/docs/concepts/containers/images\nThis field is optional to allow higher level config management to default or override\ncontainer images in workload controllers like Deployments and StatefulSets.";
          type = types.nullOr types.str;
        };
        "imagePullPolicy" = mkOption {
          description = "Image pull policy.\nOne of Always, Never, IfNotPresent.\nDefaults to Always if :latest tag is specified, or IfNotPresent otherwise.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/containers/images#updating-images";
          type = types.nullOr types.str;
        };
        "lifecycle" = mkOption {
          description = "Actions that the management system should take in response to container lifecycle events.\nCannot be updated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecycle");
        };
        "livenessProbe" = mkOption {
          description = "Periodic probe of container liveness.\nContainer will be restarted if the probe fails.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbe");
        };
        "name" = mkOption {
          description = "Name of the container specified as a DNS_LABEL.\nEach container in a pod must have a unique name (DNS_LABEL).\nCannot be updated.";
          type = types.str;
        };
        "ports" = mkOption {
          description = "List of ports to expose from the container. Not specifying a port here\nDOES NOT prevent that port from being exposed. Any port which is\nlistening on the default \"0.0.0.0\" address inside a container will be\naccessible from the network.\nModifying this array with strategic merge patch may corrupt the data.\nFor more information See https://github.com/kubernetes/kubernetes/issues/108255.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersPorts" "name" ["containerPort" "protocol"]);
          apply = attrsToList;
        };
        "readinessProbe" = mkOption {
          description = "Periodic probe of container service readiness.\nContainer will be removed from service endpoints if the probe fails.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbe");
        };
        "resizePolicy" = mkOption {
          description = "Resources resize policy for the container.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersResizePolicy"));
        };
        "resources" = mkOption {
          description = "Compute Resources required by this container.\nCannot be updated.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersResources");
        };
        "restartPolicy" = mkOption {
          description = "RestartPolicy defines the restart behavior of individual containers in a pod.\nThis field may only be set for init containers, and the only allowed value is \"Always\".\nFor non-init containers or when this field is not specified,\nthe restart behavior is defined by the Pod's restart policy and the container type.\nSetting the RestartPolicy as \"Always\" for the init container will have the following effect:\nthis init container will be continually restarted on\nexit until all regular containers have terminated. Once all regular\ncontainers have completed, all init containers with restartPolicy \"Always\"\nwill be shut down. This lifecycle differs from normal init containers and\nis often referred to as a \"sidecar\" container. Although this init\ncontainer still starts in the init container sequence, it does not wait\nfor the container to complete before proceeding to the next init\ncontainer. Instead, the next init container starts immediately after this\ninit container is started, or after any startupProbe has successfully\ncompleted.";
          type = types.nullOr types.str;
        };
        "securityContext" = mkOption {
          description = "SecurityContext defines the security options the container should be run with.\nIf set, the fields of SecurityContext override the equivalent fields of PodSecurityContext.\nMore info: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContext");
        };
        "startupProbe" = mkOption {
          description = "StartupProbe indicates that the Pod has successfully initialized.\nIf specified, no other probes are executed until this completes successfully.\nIf this probe fails, the Pod will be restarted, just as if the livenessProbe failed.\nThis can be used to provide different probe parameters at the beginning of a Pod's lifecycle,\nwhen it might take a long time to load data or warm a cache, than during steady-state operation.\nThis cannot be updated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbe");
        };
        "stdin" = mkOption {
          description = "Whether this container should allocate a buffer for stdin in the container runtime. If this\nis not set, reads from stdin in the container will always result in EOF.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "stdinOnce" = mkOption {
          description = "Whether the container runtime should close the stdin channel after it has been opened by\na single attach. When stdin is true the stdin stream will remain open across multiple attach\nsessions. If stdinOnce is set to true, stdin is opened on container start, is empty until the\nfirst client attaches to stdin, and then remains open and accepts data until the client disconnects,\nat which time stdin is closed and remains closed until the container is restarted. If this\nflag is false, a container processes that reads from stdin will never receive an EOF.\nDefault is false";
          type = types.nullOr types.bool;
        };
        "terminationMessagePath" = mkOption {
          description = "Optional: Path at which the file to which the container's termination message\nwill be written is mounted into the container's filesystem.\nMessage written is intended to be brief final status, such as an assertion failure message.\nWill be truncated by the node if greater than 4096 bytes. The total message length across\nall containers will be limited to 12kb.\nDefaults to /dev/termination-log.\nCannot be updated.";
          type = types.nullOr types.str;
        };
        "terminationMessagePolicy" = mkOption {
          description = "Indicate how the termination message should be populated. File will use the contents of\nterminationMessagePath to populate the container status message on both success and failure.\nFallbackToLogsOnError will use the last chunk of container log output if the termination\nmessage file is empty and the container exited with an error.\nThe log output is limited to 2048 bytes or 80 lines, whichever is smaller.\nDefaults to File.\nCannot be updated.";
          type = types.nullOr types.str;
        };
        "tty" = mkOption {
          description = "Whether this container should allocate a TTY for itself, also requires 'stdin' to be true.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "volumeDevices" = mkOption {
          description = "volumeDevices is the list of block devices to be used by the container.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersVolumeDevices" "name" ["devicePath"]);
          apply = attrsToList;
        };
        "volumeMounts" = mkOption {
          description = "Pod volumes to mount into the container's filesystem.\nCannot be updated.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersVolumeMounts" "name" ["mountPath"]);
          apply = attrsToList;
        };
        "workingDir" = mkOption {
          description = "Container's working directory.\nIf not specified, the container runtime's default will be used, which\nmight be configured in the container image.\nCannot be updated.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "args" = mkOverride 1002 null;
        "command" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "envFrom" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "lifecycle" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "resizePolicy" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "restartPolicy" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
        "startupProbe" = mkOverride 1002 null;
        "stdin" = mkOverride 1002 null;
        "stdinOnce" = mkOverride 1002 null;
        "terminationMessagePath" = mkOverride 1002 null;
        "terminationMessagePolicy" = mkOverride 1002 null;
        "tty" = mkOverride 1002 null;
        "volumeDevices" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "workingDir" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnv" = {
      options = {
        "name" = mkOption {
          description = "Name of the environment variable. Must be a C_IDENTIFIER.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Variable references $(VAR_NAME) are expanded\nusing the previously defined environment variables in the container and\nany service environment variables. If a variable cannot be resolved,\nthe reference in the input string will be unchanged. Double $$ are reduced\nto a single $, which allows for escaping the $(VAR_NAME) syntax: i.e.\n\"$$(VAR_NAME)\" will produce the string literal \"$(VAR_NAME)\".\nEscaped references will never be expanded, regardless of whether the variable\nexists or not.\nDefaults to \"\".";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "Source for the environment variable's value. Cannot be used if value is not empty.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvFrom" = {
      options = {
        "configMapRef" = mkOption {
          description = "The ConfigMap to select from";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvFromConfigMapRef");
        };
        "prefix" = mkOption {
          description = "An optional identifier to prepend to each key in the ConfigMap. Must be a C_IDENTIFIER.";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "The Secret to select from";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvFromSecretRef");
        };
      };

      config = {
        "configMapRef" = mkOverride 1002 null;
        "prefix" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvFromConfigMapRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the ConfigMap must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvFromSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the Secret must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFrom" = {
      options = {
        "configMapKeyRef" = mkOption {
          description = "Selects a key of a ConfigMap.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromConfigMapKeyRef");
        };
        "fieldRef" = mkOption {
          description = "Selects a field of the pod: supports metadata.name, metadata.namespace, `metadata.labels['<KEY>']`, `metadata.annotations['<KEY>']`,\nspec.nodeName, spec.serviceAccountName, status.hostIP, status.podIP, status.podIPs.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromFieldRef");
        };
        "resourceFieldRef" = mkOption {
          description = "Selects a resource of the container: only resources limits and requests\n(limits.cpu, limits.memory, limits.ephemeral-storage, requests.cpu, requests.memory and requests.ephemeral-storage) are currently supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromResourceFieldRef");
        };
        "secretKeyRef" = mkOption {
          description = "Selects a key of a secret in the pod's namespace";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromSecretKeyRef");
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromConfigMapKeyRef" = {
      options = {
        "key" = mkOption {
          description = "The key to select.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the ConfigMap or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromFieldRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "Version of the schema the FieldPath is written in terms of, defaults to \"v1\".";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "Path of the field to select in the specified API version.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromResourceFieldRef" = {
      options = {
        "containerName" = mkOption {
          description = "Container name: required for volumes, optional for env vars";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "Specifies the output format of the exposed resources, defaults to \"1\"";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "Required: resource to select";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersEnvValueFromSecretKeyRef" = {
      options = {
        "key" = mkOption {
          description = "The key of the secret to select from.  Must be a valid secret key.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "Specify whether the Secret or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecycle" = {
      options = {
        "postStart" = mkOption {
          description = "PostStart is called immediately after a container is created. If the handler fails,\nthe container is terminated and restarted according to its restart policy.\nOther management of the container blocks until the hook completes.\nMore info: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#container-hooks";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStart");
        };
        "preStop" = mkOption {
          description = "PreStop is called immediately before a container is terminated due to an\nAPI request or management event such as liveness/startup probe failure,\npreemption, resource contention, etc. The handler is not called if the\ncontainer crashes or exits. The Pod's termination grace period countdown begins before the\nPreStop hook is executed. Regardless of the outcome of the handler, the\ncontainer will eventually terminate within the Pod's termination grace\nperiod (unless delayed by finalizers). Other management of the container blocks until the hook completes\nor until the termination grace period is reached.\nMore info: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#container-hooks";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStop");
        };
      };

      config = {
        "postStart" = mkOverride 1002 null;
        "preStop" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStart" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartExec");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartHttpGet");
        };
        "sleep" = mkOption {
          description = "Sleep represents the duration that the container should sleep before being terminated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartSleep");
        };
        "tcpSocket" = mkOption {
          description = "Deprecated. TCPSocket is NOT supported as a LifecycleHandler and kept\nfor the backward compatibility. There are no validation of this field and\nlifecycle hooks will fail in runtime when tcp handler is specified.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartTcpSocket");
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "sleep" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartSleep" = {
      options = {
        "seconds" = mkOption {
          description = "Seconds is the number of seconds to sleep.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePostStartTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStop" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopExec");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopHttpGet");
        };
        "sleep" = mkOption {
          description = "Sleep represents the duration that the container should sleep before being terminated.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopSleep");
        };
        "tcpSocket" = mkOption {
          description = "Deprecated. TCPSocket is NOT supported as a LifecycleHandler and kept\nfor the backward compatibility. There are no validation of this field and\nlifecycle hooks will fail in runtime when tcp handler is specified.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopTcpSocket");
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "sleep" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopSleep" = {
      options = {
        "seconds" = mkOption {
          description = "Seconds is the number of seconds to sleep.";
          type = types.int;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLifecyclePreStopTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersLivenessProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersPorts" = {
      options = {
        "containerPort" = mkOption {
          description = "Number of port to expose on the pod's IP address.\nThis must be a valid port number, 0 < x < 65536.";
          type = types.int;
        };
        "hostIP" = mkOption {
          description = "What host IP to bind the external port to.";
          type = types.nullOr types.str;
        };
        "hostPort" = mkOption {
          description = "Number of port to expose on the host.\nIf specified, this must be a valid port number, 0 < x < 65536.\nIf HostNetwork is specified, this must match ContainerPort.\nMost containers do not need this.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "If specified, this must be an IANA_SVC_NAME and unique within the pod. Each\nnamed port in a pod must have a unique name. Name for the port that can be\nreferred to by services.";
          type = types.nullOr types.str;
        };
        "protocol" = mkOption {
          description = "Protocol for port. Must be UDP, TCP, or SCTP.\nDefaults to \"TCP\".";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hostIP" = mkOverride 1002 null;
        "hostPort" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersReadinessProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersResizePolicy" = {
      options = {
        "resourceName" = mkOption {
          description = "Name of the resource to which this resource resize policy applies.\nSupported values: cpu, memory.";
          type = types.str;
        };
        "restartPolicy" = mkOption {
          description = "Restart policy to apply when specified resource is resized.\nIf not specified, it defaults to NotRequired.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersResources" = {
      options = {
        "claims" = mkOption {
          description = "Claims lists the names of resources, defined in spec.resourceClaims,\nthat are used by this container.\n\nThis is an alpha field and requires enabling the\nDynamicResourceAllocation feature gate.\n\nThis field is immutable. It can only be set for containers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersResourcesClaims" "name" ["name"]);
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "Limits describes the maximum amount of compute resources allowed.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "Requests describes the minimum amount of compute resources required.\nIf Requests is omitted for a container, it defaults to Limits if that is explicitly specified,\notherwise to an implementation-defined value. Requests cannot exceed Limits.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersResourcesClaims" = {
      options = {
        "name" = mkOption {
          description = "Name must match the name of one entry in pod.spec.resourceClaims of\nthe Pod where this field is used. It makes that resource available\ninside a container.";
          type = types.str;
        };
        "request" = mkOption {
          description = "Request is the name chosen for a request in the referenced claim.\nIf empty, everything from the claim is made available, otherwise\nonly the result of this request.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContext" = {
      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "AllowPrivilegeEscalation controls whether a process can gain more\nprivileges than its parent process. This bool directly controls if\nthe no_new_privs flag will be set on the container process.\nAllowPrivilegeEscalation is true always when the container is:\n1) run as Privileged\n2) has CAP_SYS_ADMIN\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by this container. If set, this profile\noverrides the pod's appArmorProfile.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextAppArmorProfile");
        };
        "capabilities" = mkOption {
          description = "The capabilities to add/drop when running containers.\nDefaults to the default set of capabilities granted by the container runtime.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextCapabilities");
        };
        "privileged" = mkOption {
          description = "Run container in privileged mode.\nProcesses in privileged containers are essentially equivalent to root on the host.\nDefaults to false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "procMount denotes the type of proc mount to use for the containers.\nThe default value is Default which uses the container runtime defaults for\nreadonly paths and masked paths.\nThis requires the ProcMountType feature flag to be enabled.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "Whether this container has a read-only root filesystem.\nDefault is false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to the container.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextSeLinuxOptions");
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by this container. If seccomp options are\nprovided at both the pod & container level, the container options\noverride the pod options.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextSeccompProfile");
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options from the PodSecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextWindowsOptions");
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextAppArmorProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextCapabilities" = {
      options = {
        "add" = mkOption {
          description = "Added capabilities";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "Removed capabilities";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextSeLinuxOptions" = {
      options = {
        "level" = mkOption {
          description = "Level is SELinux level label that applies to the container.";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "Role is a SELinux role label that applies to the container.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type is a SELinux type label that applies to the container.";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "User is a SELinux user label that applies to the container.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextSeccompProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersSecurityContextWindowsOptions" = {
      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbe" = {
      options = {
        "exec" = mkOption {
          description = "Exec specifies the action to take.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeExec");
        };
        "failureThreshold" = mkOption {
          description = "Minimum consecutive failures for the probe to be considered failed after having succeeded.\nDefaults to 3. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "grpc" = mkOption {
          description = "GRPC specifies an action involving a GRPC port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeGrpc");
        };
        "httpGet" = mkOption {
          description = "HTTPGet specifies the http request to perform.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeHttpGet");
        };
        "initialDelaySeconds" = mkOption {
          description = "Number of seconds after the container has started before liveness probes are initiated.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "How often (in seconds) to perform the probe.\nDefault to 10 seconds. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "Minimum consecutive successes for the probe to be considered successful after having failed.\nDefaults to 1. Must be 1 for liveness and startup. Minimum value is 1.";
          type = types.nullOr types.int;
        };
        "tcpSocket" = mkOption {
          description = "TCPSocket specifies an action involving a TCP port.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeTcpSocket");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "Optional duration in seconds the pod needs to terminate gracefully upon probe failure.\nThe grace period is the duration in seconds after the processes running in the pod are sent\na termination signal and the time when the processes are forcibly halted with a kill signal.\nSet this value longer than the expected cleanup time for your process.\nIf this value is nil, the pod's terminationGracePeriodSeconds will be used. Otherwise, this\nvalue overrides the value provided by the pod spec.\nValue must be non-negative integer. The value zero indicates stop immediately via\nthe kill signal (no opportunity to shut down).\nThis is a beta field and requires enabling ProbeTerminationGracePeriod feature gate.\nMinimum value is 1. spec.terminationGracePeriodSeconds is used if unset.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "Number of seconds after which the probe times out.\nDefaults to 1 second. Minimum value is 1.\nMore info: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes";
          type = types.nullOr types.int;
        };
      };

      config = {
        "exec" = mkOverride 1002 null;
        "failureThreshold" = mkOverride 1002 null;
        "grpc" = mkOverride 1002 null;
        "httpGet" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "tcpSocket" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeExec" = {
      options = {
        "command" = mkOption {
          description = "Command is the command line to execute inside the container, the working directory for the\ncommand  is root ('/') in the container's filesystem. The command is simply exec'd, it is\nnot run inside a shell, so traditional shell instructions ('|', etc) won't work. To use\na shell, you need to explicitly call out to that shell.\nExit status of 0 is treated as live/healthy and non-zero is unhealthy.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "command" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeGrpc" = {
      options = {
        "port" = mkOption {
          description = "Port number of the gRPC service. Number must be in the range 1 to 65535.";
          type = types.int;
        };
        "service" = mkOption {
          description = "Service is the name of the service to place in the gRPC HealthCheckRequest\n(see https://github.com/grpc/grpc/blob/master/doc/health-checking.md).\n\nIf this is not specified, the default behavior is defined by gRPC.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "service" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeHttpGet" = {
      options = {
        "host" = mkOption {
          description = "Host name to connect to, defaults to the pod IP. You probably want to set\n\"Host\" in httpHeaders instead.";
          type = types.nullOr types.str;
        };
        "httpHeaders" = mkOption {
          description = "Custom headers to set in the request. HTTP allows repeated headers.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeHttpGetHttpHeaders" "name" []);
          apply = attrsToList;
        };
        "path" = mkOption {
          description = "Path to access on the HTTP server.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Name or number of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
        "scheme" = mkOption {
          description = "Scheme to use for connecting to the host.\nDefaults to HTTP.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
        "httpHeaders" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeHttpGetHttpHeaders" = {
      options = {
        "name" = mkOption {
          description = "The header field name.\nThis will be canonicalized upon output, so case-variant names will be understood as the same header.";
          type = types.str;
        };
        "value" = mkOption {
          description = "The header field value";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersStartupProbeTcpSocket" = {
      options = {
        "host" = mkOption {
          description = "Optional: Host name to connect to, defaults to the pod IP.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Number or name of the port to access on the container.\nNumber must be in the range 1 to 65535.\nName must be an IANA_SVC_NAME.";
          type = types.either types.int types.str;
        };
      };

      config = {
        "host" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersVolumeDevices" = {
      options = {
        "devicePath" = mkOption {
          description = "devicePath is the path inside of the container that the device will be mapped to.";
          type = types.str;
        };
        "name" = mkOption {
          description = "name must match the name of a persistentVolumeClaim in the pod";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecInitContainersVolumeMounts" = {
      options = {
        "mountPath" = mkOption {
          description = "Path within the container at which the volume should be mounted.  Must\nnot contain ':'.";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "mountPropagation determines how mounts are propagated from the host\nto container and the other way around.\nWhen not set, MountPropagationNone is used.\nThis field is beta in 1.10.\nWhen RecursiveReadOnly is set to IfPossible or to Enabled, MountPropagation must be None or unspecified\n(which defaults to None).";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "This must match the Name of a Volume.";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "Mounted read-only if true, read-write otherwise (false or unspecified).\nDefaults to false.";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "RecursiveReadOnly specifies whether read-only mounts should be handled\nrecursively.\n\nIf ReadOnly is false, this field has no meaning and must be unspecified.\n\nIf ReadOnly is true, and this field is set to Disabled, the mount is not made\nrecursively read-only.  If this field is set to IfPossible, the mount is made\nrecursively read-only, if it is supported by the container runtime.  If this\nfield is set to Enabled, the mount is made recursively read-only if it is\nsupported by the container runtime, otherwise the pod will not be started and\nan error will be generated to indicate the reason.\n\nIf this field is set to IfPossible or Enabled, MountPropagation must be set to\nNone (or be unspecified, which defaults to None).\n\nIf this field is not specified, it is treated as an equivalent of Disabled.";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "Path within the volume from which the container's volume should be mounted.\nDefaults to \"\" (volume's root).";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "Expanded path within the volume from which the container's volume should be mounted.\nBehaves similarly to SubPath but environment variable references $(VAR_NAME) are expanded using the container's environment.\nDefaults to \"\" (volume's root).\nSubPathExpr and SubPath are mutually exclusive.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecOs" = {
      options = {
        "name" = mkOption {
          description = "Name is the name of the operating system. The currently supported values are linux and windows.\nAdditional value may be defined in future and can be one of:\nhttps://github.com/opencontainers/runtime-spec/blob/master/config.md#platform-specific-configuration\nClients should expect to handle additional values and treat unrecognized values in this field as os: null";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecReadinessGates" = {
      options = {
        "conditionType" = mkOption {
          description = "ConditionType refers to a condition in the pod's condition list with matching type.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecResourceClaims" = {
      options = {
        "name" = mkOption {
          description = "Name uniquely identifies this resource claim inside the pod.\nThis must be a DNS_LABEL.";
          type = types.str;
        };
        "resourceClaimName" = mkOption {
          description = "ResourceClaimName is the name of a ResourceClaim object in the same\nnamespace as this pod.\n\nExactly one of ResourceClaimName and ResourceClaimTemplateName must\nbe set.";
          type = types.nullOr types.str;
        };
        "resourceClaimTemplateName" = mkOption {
          description = "ResourceClaimTemplateName is the name of a ResourceClaimTemplate\nobject in the same namespace as this pod.\n\nThe template will be used to create a new ResourceClaim, which will\nbe bound to this pod. When this pod is deleted, the ResourceClaim\nwill also be deleted. The pod name and resource name, along with a\ngenerated component, will be used to form a unique name for the\nResourceClaim, which will be recorded in pod.status.resourceClaimStatuses.\n\nThis field is immutable and no changes will be made to the\ncorresponding ResourceClaim by the control plane after creating the\nResourceClaim.\n\nExactly one of ResourceClaimName and ResourceClaimTemplateName must\nbe set.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "resourceClaimName" = mkOverride 1002 null;
        "resourceClaimTemplateName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSchedulingGates" = {
      options = {
        "name" = mkOption {
          description = "Name of the scheduling gate.\nEach scheduling gate must have a unique name field.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContext" = {
      options = {
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by the containers in this pod.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextAppArmorProfile");
        };
        "fsGroup" = mkOption {
          description = "A special supplemental group that applies to all containers in a pod.\nSome volume types allow the Kubelet to change the ownership of that volume\nto be owned by the pod:\n\n1. The owning GID will be the FSGroup\n2. The setgid bit is set (new files created in the volume will be owned by FSGroup)\n3. The permission bits are OR'd with rw-rw----\n\nIf unset, the Kubelet will not modify the ownership and permissions of any volume.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "fsGroupChangePolicy defines behavior of changing ownership and permission of the volume\nbefore being exposed inside Pod. This field will only apply to\nvolume types which support fsGroup based ownership(and permissions).\nIt will have no effect on ephemeral volume types such as: secret, configmaps\nand emptydir.\nValid values are \"OnRootMismatch\" and \"Always\". If not specified, \"Always\" is used.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in SecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence\nfor that container.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in SecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in SecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence\nfor that container.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to all containers.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in SecurityContext.  If set in\nboth SecurityContext and PodSecurityContext, the value specified in SecurityContext\ntakes precedence for that container.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextSeLinuxOptions");
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by the containers in this pod.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextSeccompProfile");
        };
        "supplementalGroups" = mkOption {
          description = "A list of groups applied to the first process run in each container, in\naddition to the container's primary GID and fsGroup (if specified).  If\nthe SupplementalGroupsPolicy feature is enabled, the\nsupplementalGroupsPolicy field determines whether these are in addition\nto or instead of any group memberships defined in the container image.\nIf unspecified, no additional groups are added, though group memberships\ndefined in the container image may still be used, depending on the\nsupplementalGroupsPolicy field.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "Defines how supplemental groups of the first container processes are calculated.\nValid values are \"Merge\" and \"Strict\". If not specified, \"Merge\" is used.\n(Alpha) Using the field requires the SupplementalGroupsPolicy feature gate to be enabled\nand the container runtime must implement support for this feature.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "Sysctls hold a list of namespaced sysctls used for the pod. Pods with unsupported\nsysctls (by the container runtime) might fail to launch.\nNote that this field cannot be set when spec.os.name is windows.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextSysctls" "name" []);
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options within a container's SecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextWindowsOptions");
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextAppArmorProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextSeLinuxOptions" = {
      options = {
        "level" = mkOption {
          description = "Level is SELinux level label that applies to the container.";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "Role is a SELinux role label that applies to the container.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "Type is a SELinux type label that applies to the container.";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "User is a SELinux user label that applies to the container.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextSeccompProfile" = {
      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextSysctls" = {
      options = {
        "name" = mkOption {
          description = "Name of a property to set";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value of a property to set";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecSecurityContextWindowsOptions" = {
      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTolerations" = {
      options = {
        "effect" = mkOption {
          description = "Effect indicates the taint effect to match. Empty means match all taint effects.\nWhen specified, allowed values are NoSchedule, PreferNoSchedule and NoExecute.";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "Key is the taint key that the toleration applies to. Empty means match all taint keys.\nIf the key is empty, operator must be Exists; this combination means to match all values and all keys.";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "Operator represents a key's relationship to the value.\nValid operators are Exists and Equal. Defaults to Equal.\nExists is equivalent to wildcard for value, so that a pod can\ntolerate all taints of a particular category.";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "TolerationSeconds represents the period of time the toleration (which must be\nof effect NoExecute, otherwise this field is ignored) tolerates the taint. By default,\nit is not set, which means tolerate the taint forever (do not evict). Zero and\nnegative values will be treated as 0 (evict immediately) by the system.";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "Value is the taint value the toleration matches to.\nIf the operator is Exists, the value should be empty, otherwise just a regular string.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTopologySpreadConstraints" = {
      options = {
        "labelSelector" = mkOption {
          description = "LabelSelector is used to find matching pods.\nPods that match this label selector are counted to determine the number of pods\nin their corresponding topology domain.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTopologySpreadConstraintsLabelSelector");
        };
        "matchLabelKeys" = mkOption {
          description = "MatchLabelKeys is a set of pod label keys to select the pods over which\nspreading will be calculated. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are ANDed with labelSelector\nto select the group of existing pods over which spreading will be calculated\nfor the incoming pod. The same key is forbidden to exist in both MatchLabelKeys and LabelSelector.\nMatchLabelKeys cannot be set when LabelSelector isn't set.\nKeys that don't exist in the incoming pod labels will\nbe ignored. A null or empty list means only match against labelSelector.\n\nThis is a beta field and requires the MatchLabelKeysInPodTopologySpread feature gate to be enabled (enabled by default).";
          type = types.nullOr (types.listOf types.str);
        };
        "maxSkew" = mkOption {
          description = "MaxSkew describes the degree to which pods may be unevenly distributed.\nWhen `whenUnsatisfiable=DoNotSchedule`, it is the maximum permitted difference\nbetween the number of matching pods in the target topology and the global minimum.\nThe global minimum is the minimum number of matching pods in an eligible domain\nor zero if the number of eligible domains is less than MinDomains.\nFor example, in a 3-zone cluster, MaxSkew is set to 1, and pods with the same\nlabelSelector spread as 2/2/1:\nIn this case, the global minimum is 1.\n| zone1 | zone2 | zone3 |\n|  P P  |  P P  |   P   |\n- if MaxSkew is 1, incoming pod can only be scheduled to zone3 to become 2/2/2;\nscheduling it onto zone1(zone2) would make the ActualSkew(3-1) on zone1(zone2)\nviolate MaxSkew(1).\n- if MaxSkew is 2, incoming pod can be scheduled onto any zone.\nWhen `whenUnsatisfiable=ScheduleAnyway`, it is used to give higher precedence\nto topologies that satisfy it.\nIt's a required field. Default value is 1 and 0 is not allowed.";
          type = types.int;
        };
        "minDomains" = mkOption {
          description = "MinDomains indicates a minimum number of eligible domains.\nWhen the number of eligible domains with matching topology keys is less than minDomains,\nPod Topology Spread treats \"global minimum\" as 0, and then the calculation of Skew is performed.\nAnd when the number of eligible domains with matching topology keys equals or greater than minDomains,\nthis value has no effect on scheduling.\nAs a result, when the number of eligible domains is less than minDomains,\nscheduler won't schedule more than maxSkew Pods to those domains.\nIf value is nil, the constraint behaves as if MinDomains is equal to 1.\nValid values are integers greater than 0.\nWhen value is not nil, WhenUnsatisfiable must be DoNotSchedule.\n\nFor example, in a 3-zone cluster, MaxSkew is set to 2, MinDomains is set to 5 and pods with the same\nlabelSelector spread as 2/2/2:\n| zone1 | zone2 | zone3 |\n|  P P  |  P P  |  P P  |\nThe number of domains is less than 5(MinDomains), so \"global minimum\" is treated as 0.\nIn this situation, new pod with the same labelSelector cannot be scheduled,\nbecause computed skew will be 3(3 - 0) if new Pod is scheduled to any of the three zones,\nit will violate MaxSkew.";
          type = types.nullOr types.int;
        };
        "nodeAffinityPolicy" = mkOption {
          description = "NodeAffinityPolicy indicates how we will treat Pod's nodeAffinity/nodeSelector\nwhen calculating pod topology spread skew. Options are:\n- Honor: only nodes matching nodeAffinity/nodeSelector are included in the calculations.\n- Ignore: nodeAffinity/nodeSelector are ignored. All nodes are included in the calculations.\n\nIf this value is nil, the behavior is equivalent to the Honor policy.\nThis is a beta-level feature default enabled by the NodeInclusionPolicyInPodTopologySpread feature flag.";
          type = types.nullOr types.str;
        };
        "nodeTaintsPolicy" = mkOption {
          description = "NodeTaintsPolicy indicates how we will treat node taints when calculating\npod topology spread skew. Options are:\n- Honor: nodes without taints, along with tainted nodes for which the incoming pod\nhas a toleration, are included.\n- Ignore: node taints are ignored. All nodes are included.\n\nIf this value is nil, the behavior is equivalent to the Ignore policy.\nThis is a beta-level feature default enabled by the NodeInclusionPolicyInPodTopologySpread feature flag.";
          type = types.nullOr types.str;
        };
        "topologyKey" = mkOption {
          description = "TopologyKey is the key of node labels. Nodes that have a label with this key\nand identical values are considered to be in the same topology.\nWe consider each <key, value> as a \"bucket\", and try to put balanced number\nof pods into each bucket.\nWe define a domain as a particular instance of a topology.\nAlso, we define an eligible domain as a domain whose nodes meet the requirements of\nnodeAffinityPolicy and nodeTaintsPolicy.\ne.g. If TopologyKey is \"kubernetes.io/hostname\", each Node is a domain of that topology.\nAnd, if TopologyKey is \"topology.kubernetes.io/zone\", each zone is a domain of that topology.\nIt's a required field.";
          type = types.str;
        };
        "whenUnsatisfiable" = mkOption {
          description = "WhenUnsatisfiable indicates how to deal with a pod if it doesn't satisfy\nthe spread constraint.\n- DoNotSchedule (default) tells the scheduler not to schedule it.\n- ScheduleAnyway tells the scheduler to schedule the pod in any location,\n  but giving higher precedence to topologies that would help reduce the\n  skew.\nA constraint is considered \"Unsatisfiable\" for an incoming pod\nif and only if every possible node assignment for that pod would violate\n\"MaxSkew\" on some topology.\nFor example, in a 3-zone cluster, MaxSkew is set to 1, and pods with the same\nlabelSelector spread as 3/1/1:\n| zone1 | zone2 | zone3 |\n| P P P |   P   |   P   |\nIf WhenUnsatisfiable is set to DoNotSchedule, incoming pod can only be scheduled\nto zone2(zone3) to become 3/2/1(3/1/2) as ActualSkew(2-1) on zone2(zone3) satisfies\nMaxSkew(1). In other words, the cluster can still be imbalanced, but scheduler\nwon't make it *more* imbalanced.\nIt's a required field.";
          type = types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "matchLabelKeys" = mkOverride 1002 null;
        "minDomains" = mkOverride 1002 null;
        "nodeAffinityPolicy" = mkOverride 1002 null;
        "nodeTaintsPolicy" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTopologySpreadConstraintsLabelSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTopologySpreadConstraintsLabelSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecTopologySpreadConstraintsLabelSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumes" = {
      options = {
        "awsElasticBlockStore" = mkOption {
          description = "awsElasticBlockStore represents an AWS Disk resource that is attached to a\nkubelet's host machine and then exposed to the pod.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#awselasticblockstore";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesAwsElasticBlockStore");
        };
        "azureDisk" = mkOption {
          description = "azureDisk represents an Azure Data Disk mount on the host and bind mount to the pod.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "azureFile represents an Azure File Service mount on the host and bind mount to the pod.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "cephFS represents a Ceph FS mount on the host that shares a pod's lifetime";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "cinder represents a cinder volume attached and mounted on kubelets host machine.\nMore info: https://examples.k8s.io/mysql-cinder-pd/README.md";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCinder");
        };
        "configMap" = mkOption {
          description = "configMap represents a configMap that should populate this volume";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "csi (Container Storage Interface) represents ephemeral storage that is handled by certain external CSI drivers (Beta feature).";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "downwardAPI represents downward API about the pod that should populate this volume";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "emptyDir represents a temporary directory that shares a pod's lifetime.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#emptydir";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "ephemeral represents a volume that is handled by a cluster storage driver.\nThe volume's lifecycle is tied to the pod that defines it - it will be created before the pod starts,\nand deleted when the pod is removed.\n\nUse this if:\na) the volume is only needed while the pod runs,\nb) features of normal volumes like restoring from snapshot or capacity\n   tracking are needed,\nc) the storage driver is specified through a storage class, and\nd) the storage driver supports dynamic volume provisioning through\n   a PersistentVolumeClaim (see EphemeralVolumeSource for more\n   information on the connection between this volume type\n   and PersistentVolumeClaim).\n\nUse PersistentVolumeClaim or one of the vendor-specific\nAPIs for volumes that persist for longer than the lifecycle\nof an individual pod.\n\nUse CSI for light-weight local ephemeral volumes if the CSI driver is meant to\nbe used that way - see the documentation of the driver for\nmore information.\n\nA pod can use both types of ephemeral volumes and\npersistent volumes at the same time.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "fc represents a Fibre Channel resource that is attached to a kubelet's host machine and then exposed to the pod.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "flexVolume represents a generic volume resource that is\nprovisioned/attached using an exec based plugin.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "flocker represents a Flocker volume attached to a kubelet's host machine. This depends on the Flocker control service being running";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "gcePersistentDisk represents a GCE Disk resource that is attached to a\nkubelet's host machine and then exposed to the pod.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#gcepersistentdisk";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesGcePersistentDisk");
        };
        "gitRepo" = mkOption {
          description = "gitRepo represents a git repository at a particular revision.\nDEPRECATED: GitRepo is deprecated. To provision a container with a git repo, mount an\nEmptyDir into an InitContainer that clones the repo using git, then mount the EmptyDir\ninto the Pod's container.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "glusterfs represents a Glusterfs mount on the host that shares a pod's lifetime.\nMore info: https://examples.k8s.io/volumes/glusterfs/README.md";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "hostPath represents a pre-existing file or directory on the host\nmachine that is directly exposed to the container. This is generally\nused for system agents or other privileged things that are allowed\nto see the host machine. Most containers will NOT need this.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#hostpath";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesHostPath");
        };
        "image" = mkOption {
          description = "image represents an OCI object (a container image or artifact) pulled and mounted on the kubelet's host machine.\nThe volume is resolved at pod startup depending on which PullPolicy value is provided:\n\n- Always: the kubelet always attempts to pull the reference. Container creation will fail If the pull fails.\n- Never: the kubelet never pulls the reference and only uses a local image or artifact. Container creation will fail if the reference isn't present.\n- IfNotPresent: the kubelet pulls if the reference isn't already present on disk. Container creation will fail if the reference isn't present and the pull fails.\n\nThe volume gets re-resolved if the pod gets deleted and recreated, which means that new remote content will become available on pod recreation.\nA failure to resolve or pull the image during pod startup will block containers from starting and may add significant latency. Failures will be retried using normal volume backoff and will be reported on the pod reason and message.\nThe types of objects that may be mounted by this volume are defined by the container runtime implementation on a host machine and at minimum must include all valid types supported by the container image field.\nThe OCI object gets mounted in a single directory (spec.containers[*].volumeMounts.mountPath) by merging the manifest layers in the same way as for container images.\nThe volume will be mounted read-only (ro) and non-executable files (noexec).\nSub path mounts for containers are not supported (spec.containers[*].volumeMounts.subpath).\nThe field spec.securityContext.fsGroupChangePolicy has no effect on this volume type.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesImage");
        };
        "iscsi" = mkOption {
          description = "iscsi represents an ISCSI Disk resource that is attached to a\nkubelet's host machine and then exposed to the pod.\nMore info: https://examples.k8s.io/volumes/iscsi/README.md";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesIscsi");
        };
        "name" = mkOption {
          description = "name of the volume.\nMust be a DNS_LABEL and unique within the pod.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "nfs represents an NFS mount on the host that shares a pod's lifetime\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#nfs";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "persistentVolumeClaimVolumeSource represents a reference to a\nPersistentVolumeClaim in the same namespace.\nMore info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#persistentvolumeclaims";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesPersistentVolumeClaim");
        };
        "photonPersistentDisk" = mkOption {
          description = "photonPersistentDisk represents a PhotonController persistent disk attached and mounted on kubelets host machine";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesPhotonPersistentDisk");
        };
        "portworxVolume" = mkOption {
          description = "portworxVolume represents a portworx volume attached and mounted on kubelets host machine";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "projected items for all in one resources secrets, configmaps, and downward API";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "quobyte represents a Quobyte mount on the host that shares a pod's lifetime";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "rbd represents a Rados Block Device mount on the host that shares a pod's lifetime.\nMore info: https://examples.k8s.io/volumes/rbd/README.md";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "scaleIO represents a ScaleIO persistent volume attached and mounted on Kubernetes nodes.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "secret represents a secret that should populate this volume.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#secret";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesSecret");
        };
        "storageos" = mkOption {
          description = "storageOS represents a StorageOS volume attached and mounted on Kubernetes nodes.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "vsphereVolume represents a vSphere volume attached and mounted on kubelets host machine";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesAwsElasticBlockStore" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type of the volume that you want to mount.\nTip: Ensure that the filesystem type is supported by the host operating system.\nExamples: \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#awselasticblockstore";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "partition is the partition in the volume that you want to mount.\nIf omitted, the default is to mount by volume name.\nExamples: For volume /dev/sda1, you specify the partition as \"1\".\nSimilarly, the volume partition for /dev/sda is \"0\" (or you can leave the property empty).";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "readOnly value true will force the readOnly setting in VolumeMounts.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#awselasticblockstore";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "volumeID is unique ID of the persistent disk resource in AWS (Amazon EBS volume).\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#awselasticblockstore";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesAzureDisk" = {
      options = {
        "cachingMode" = mkOption {
          description = "cachingMode is the Host Caching mode: None, Read Only, Read Write.";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "diskName is the Name of the data disk in the blob storage";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "diskURI is the URI of data disk in the blob storage";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "fsType is Filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "kind expected values are Shared: multiple blob disks per storage account  Dedicated: single blob disk per storage account  Managed: azure managed data disk (only in managed availability set). defaults to shared";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly Defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesAzureFile" = {
      options = {
        "readOnly" = mkOption {
          description = "readOnly defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "secretName is the  name of secret that contains Azure Storage Account Name and Key";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "shareName is the azure share Name";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCephfs" = {
      options = {
        "monitors" = mkOption {
          description = "monitors is Required: Monitors is a collection of Ceph monitors\nMore info: https://examples.k8s.io/volumes/cephfs/README.md#how-to-use-it";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "path is Optional: Used as the mounted root, rather than the full Ceph tree, default is /";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly is Optional: Defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.\nMore info: https://examples.k8s.io/volumes/cephfs/README.md#how-to-use-it";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "secretFile is Optional: SecretFile is the path to key ring for User, default is /etc/ceph/user.secret\nMore info: https://examples.k8s.io/volumes/cephfs/README.md#how-to-use-it";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "secretRef is Optional: SecretRef is reference to the authentication secret for User, default is empty.\nMore info: https://examples.k8s.io/volumes/cephfs/README.md#how-to-use-it";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCephfsSecretRef");
        };
        "user" = mkOption {
          description = "user is optional: User is the rados user name, default is admin\nMore info: https://examples.k8s.io/volumes/cephfs/README.md#how-to-use-it";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCephfsSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCinder" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nExamples: \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.\nMore info: https://examples.k8s.io/mysql-cinder-pd/README.md";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.\nMore info: https://examples.k8s.io/mysql-cinder-pd/README.md";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "secretRef is optional: points to a secret object containing parameters used to connect\nto OpenStack.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCinderSecretRef");
        };
        "volumeID" = mkOption {
          description = "volumeID used to identify the volume in cinder.\nMore info: https://examples.k8s.io/mysql-cinder-pd/README.md";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCinderSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesConfigMap" = {
      options = {
        "defaultMode" = mkOption {
          description = "defaultMode is optional: mode bits used to set permissions on created files by default.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nDefaults to 0644.\nDirectories within the path are not affected by this setting.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "items if unspecified, each key-value pair in the Data field of the referenced\nConfigMap will be projected into the volume as a file whose name is the\nkey and content is the value. If specified, the listed keys will be\nprojected into the specified paths, and unlisted keys will not be\npresent. If a key is specified which is not present in the ConfigMap,\nthe volume setup will error unless it is marked optional. Paths must be\nrelative and may not contain the '..' path or start with '..'.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesConfigMapItems"));
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "optional specify whether the ConfigMap or its keys must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesConfigMapItems" = {
      options = {
        "key" = mkOption {
          description = "key is the key to project.";
          type = types.str;
        };
        "mode" = mkOption {
          description = "mode is Optional: mode bits used to set permissions on this file.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nIf not specified, the volume defaultMode will be used.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "path is the relative path of the file to map the key to.\nMay not be an absolute path.\nMay not contain the path element '..'.\nMay not start with the string '..'.";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCsi" = {
      options = {
        "driver" = mkOption {
          description = "driver is the name of the CSI driver that handles this volume.\nConsult with your admin for the correct name as registered in the cluster.";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "fsType to mount. Ex. \"ext4\", \"xfs\", \"ntfs\".\nIf not provided, the empty value is passed to the associated CSI driver\nwhich will determine the default filesystem to apply.";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "nodePublishSecretRef is a reference to the secret object containing\nsensitive information to pass to the CSI driver to complete the CSI\nNodePublishVolume and NodeUnpublishVolume calls.\nThis field is optional, and  may be empty if no secret is required. If the\nsecret object contains more than one secret, all secret references are passed.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCsiNodePublishSecretRef");
        };
        "readOnly" = mkOption {
          description = "readOnly specifies a read-only configuration for the volume.\nDefaults to false (read/write).";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "volumeAttributes stores driver-specific properties that are passed to the CSI\ndriver. Consult your driver's documentation for supported values.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesCsiNodePublishSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPI" = {
      options = {
        "defaultMode" = mkOption {
          description = "Optional: mode bits to use on created files by default. Must be a\nOptional: mode bits used to set permissions on created files by default.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nDefaults to 0644.\nDirectories within the path are not affected by this setting.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "Items is a list of downward API volume file";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPIItems"));
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPIItems" = {
      options = {
        "fieldRef" = mkOption {
          description = "Required: Selects a field of the pod: only annotations, labels, name, namespace and uid are supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPIItemsFieldRef");
        };
        "mode" = mkOption {
          description = "Optional: mode bits used to set permissions on this file, must be an octal value\nbetween 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nIf not specified, the volume defaultMode will be used.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "Required: Path is  the relative path name of the file to be created. Must not be absolute or contain the '..' path. Must be utf-8 encoded. The first item of the relative path must not start with '..'";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "Selects a resource of the container: only resources limits and requests\n(limits.cpu, limits.memory, requests.cpu and requests.memory) are currently supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPIItemsResourceFieldRef");
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPIItemsFieldRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "Version of the schema the FieldPath is written in terms of, defaults to \"v1\".";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "Path of the field to select in the specified API version.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesDownwardAPIItemsResourceFieldRef" = {
      options = {
        "containerName" = mkOption {
          description = "Container name: required for volumes, optional for env vars";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "Specifies the output format of the exposed resources, defaults to \"1\"";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "Required: resource to select";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEmptyDir" = {
      options = {
        "medium" = mkOption {
          description = "medium represents what type of storage medium should back this directory.\nThe default is \"\" which means to use the node's default medium.\nMust be an empty string (default) or Memory.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#emptydir";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "sizeLimit is the total amount of local storage required for this EmptyDir volume.\nThe size limit is also applicable for memory medium.\nThe maximum usage on memory medium EmptyDir would be the minimum value between\nthe SizeLimit specified here and the sum of memory limits of all containers in a pod.\nThe default is nil which means that the limit is undefined.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#emptydir";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeral" = {
      options = {
        "volumeClaimTemplate" = mkOption {
          description = "Will be used to create a stand-alone PVC to provision the volume.\nThe pod in which this EphemeralVolumeSource is embedded will be the\nowner of the PVC, i.e. the PVC will be deleted together with the\npod.  The name of the PVC will be `<pod name>-<volume name>` where\n`<volume name>` is the name from the `PodSpec.Volumes` array\nentry. Pod validation will reject the pod if the concatenated name\nis not valid for a PVC (for example, too long).\n\nAn existing PVC with that name that is not owned by the pod\nwill *not* be used for the pod to avoid using an unrelated\nvolume by mistake. Starting the pod is then blocked until\nthe unrelated PVC is removed. If such a pre-created PVC is\nmeant to be used by the pod, the PVC has to updated with an\nowner reference to the pod once the pod exists. Normally\nthis should not be necessary, but it may be useful when\nmanually reconstructing a broken cluster.\n\nThis field is read-only and no changes will be made by Kubernetes\nto the PVC after it has been created.\n\nRequired, must not be nil.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplate");
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplate" = {
      options = {
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The specification for the PersistentVolumeClaim. The entire content is\ncopied unchanged into the PVC that gets created from this\ntemplate. The same fields as in a PersistentVolumeClaim\nare also valid here.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpec" = {
      options = {
        "accessModes" = mkOption {
          description = "accessModes contains the desired access modes the volume should have.\nMore info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#access-modes-1";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "dataSource field can be used to specify either:\n* An existing VolumeSnapshot object (snapshot.storage.k8s.io/VolumeSnapshot)\n* An existing PVC (PersistentVolumeClaim)\nIf the provisioner or an external controller can support the specified data source,\nit will create a new volume based on the contents of the specified data source.\nWhen the AnyVolumeDataSource feature gate is enabled, dataSource contents will be copied to dataSourceRef,\nand dataSourceRef contents will be copied to dataSource when dataSourceRef.namespace is not specified.\nIf the namespace is specified, then dataSourceRef will not be copied to dataSource.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecDataSource");
        };
        "dataSourceRef" = mkOption {
          description = "dataSourceRef specifies the object from which to populate the volume with data, if a non-empty\nvolume is desired. This may be any object from a non-empty API group (non\ncore object) or a PersistentVolumeClaim object.\nWhen this field is specified, volume binding will only succeed if the type of\nthe specified object matches some installed volume populator or dynamic\nprovisioner.\nThis field will replace the functionality of the dataSource field and as such\nif both fields are non-empty, they must have the same value. For backwards\ncompatibility, when namespace isn't specified in dataSourceRef,\nboth fields (dataSource and dataSourceRef) will be set to the same\nvalue automatically if one of them is empty and the other is non-empty.\nWhen namespace is specified in dataSourceRef,\ndataSource isn't set to the same value and must be empty.\nThere are three important differences between dataSource and dataSourceRef:\n* While dataSource only allows two specific types of objects, dataSourceRef\n  allows any non-core object, as well as PersistentVolumeClaim objects.\n* While dataSource ignores disallowed values (dropping them), dataSourceRef\n  preserves all values, and generates an error if a disallowed value is\n  specified.\n* While dataSource only allows local objects, dataSourceRef allows objects\n  in any namespaces.\n(Beta) Using this field requires the AnyVolumeDataSource feature gate to be enabled.\n(Alpha) Using the namespace field of dataSourceRef requires the CrossNamespaceVolumeDataSource feature gate to be enabled.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef");
        };
        "resources" = mkOption {
          description = "resources represents the minimum resources the volume should have.\nIf RecoverVolumeExpansionFailure feature is enabled users are allowed to specify resource requirements\nthat are lower than previous value but must still be higher than capacity recorded in the\nstatus field of the claim.\nMore info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#resources";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecResources");
        };
        "selector" = mkOption {
          description = "selector is a label query over volumes to consider for binding.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecSelector");
        };
        "storageClassName" = mkOption {
          description = "storageClassName is the name of the StorageClass required by the claim.\nMore info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#class-1";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "volumeAttributesClassName may be used to set the VolumeAttributesClass used by this claim.\nIf specified, the CSI driver will create or update the volume with the attributes defined\nin the corresponding VolumeAttributesClass. This has a different purpose than storageClassName,\nit can be changed after the claim is created. An empty string value means that no VolumeAttributesClass\nwill be applied to the claim but it's not allowed to reset this field to empty string once it is set.\nIf unspecified and the PersistentVolumeClaim is unbound, the default VolumeAttributesClass\nwill be set by the persistentvolume controller if it exists.\nIf the resource referred to by volumeAttributesClass does not exist, this PersistentVolumeClaim will be\nset to a Pending state, as reflected by the modifyVolumeStatus field, until such as a resource\nexists.\nMore info: https://kubernetes.io/docs/concepts/storage/volume-attributes-classes/\n(Beta) Using this field requires the VolumeAttributesClass feature gate to be enabled (off by default).";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "volumeMode defines what type of volume is required by the claim.\nValue of Filesystem is implied when not included in claim spec.";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "volumeName is the binding reference to the PersistentVolume backing this claim.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {
      options = {
        "apiGroup" = mkOption {
          description = "APIGroup is the group for the resource being referenced.\nIf APIGroup is not specified, the specified Kind must be in the core API group.\nFor any other third-party types, APIGroup is required.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is the type of resource being referenced";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of resource being referenced";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {
      options = {
        "apiGroup" = mkOption {
          description = "APIGroup is the group for the resource being referenced.\nIf APIGroup is not specified, the specified Kind must be in the core API group.\nFor any other third-party types, APIGroup is required.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is the type of resource being referenced";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of resource being referenced";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of resource being referenced\nNote that when a namespace is specified, a gateway.networking.k8s.io/ReferenceGrant object is required in the referent namespace to allow that namespace's owner to accept the reference. See the ReferenceGrant documentation for details.\n(Alpha) This field requires the CrossNamespaceVolumeDataSource feature gate to be enabled.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecResources" = {
      options = {
        "limits" = mkOption {
          description = "Limits describes the maximum amount of compute resources allowed.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "Requests describes the minimum amount of compute resources required.\nIf Requests is omitted for a container, it defaults to Limits if that is explicitly specified,\notherwise to an implementation-defined value. Requests cannot exceed Limits.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFc" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "lun is Optional: FC target lun number";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "readOnly is Optional: Defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "targetWWNs is Optional: FC target worldwide names (WWNs)";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "wwids Optional: FC volume world wide identifiers (wwids)\nEither wwids or combination of targetWWNs and lun must be set, but not both simultaneously.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFlexVolume" = {
      options = {
        "driver" = mkOption {
          description = "driver is the name of the driver to use for this volume.";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "fsType is the filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\". The default filesystem depends on FlexVolume script.";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "options is Optional: this field holds extra command options if any.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "readOnly is Optional: defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "secretRef is Optional: secretRef is reference to the secret object containing\nsensitive information to pass to the plugin scripts. This may be\nempty if no secret object is specified. If the secret object\ncontains more than one secret, all secrets are passed to the plugin\nscripts.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFlexVolumeSecretRef");
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFlexVolumeSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesFlocker" = {
      options = {
        "datasetName" = mkOption {
          description = "datasetName is Name of the dataset stored as metadata -> name on the dataset for Flocker\nshould be considered as deprecated";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "datasetUUID is the UUID of the dataset. This is unique identifier of a Flocker dataset";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesGcePersistentDisk" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is filesystem type of the volume that you want to mount.\nTip: Ensure that the filesystem type is supported by the host operating system.\nExamples: \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#gcepersistentdisk";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "partition is the partition in the volume that you want to mount.\nIf omitted, the default is to mount by volume name.\nExamples: For volume /dev/sda1, you specify the partition as \"1\".\nSimilarly, the volume partition for /dev/sda is \"0\" (or you can leave the property empty).\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#gcepersistentdisk";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "pdName is unique name of the PD resource in GCE. Used to identify the disk in GCE.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#gcepersistentdisk";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly here will force the ReadOnly setting in VolumeMounts.\nDefaults to false.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#gcepersistentdisk";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesGitRepo" = {
      options = {
        "directory" = mkOption {
          description = "directory is the target directory name.\nMust not contain or start with '..'.  If '.' is supplied, the volume directory will be the\ngit repository.  Otherwise, if specified, the volume will contain the git repository in\nthe subdirectory with the given name.";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "repository is the URL";
          type = types.str;
        };
        "revision" = mkOption {
          description = "revision is the commit hash for the specified revision.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesGlusterfs" = {
      options = {
        "endpoints" = mkOption {
          description = "endpoints is the endpoint name that details Glusterfs topology.\nMore info: https://examples.k8s.io/volumes/glusterfs/README.md#create-a-pod";
          type = types.str;
        };
        "path" = mkOption {
          description = "path is the Glusterfs volume path.\nMore info: https://examples.k8s.io/volumes/glusterfs/README.md#create-a-pod";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly here will force the Glusterfs volume to be mounted with read-only permissions.\nDefaults to false.\nMore info: https://examples.k8s.io/volumes/glusterfs/README.md#create-a-pod";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesHostPath" = {
      options = {
        "path" = mkOption {
          description = "path of the directory on the host.\nIf the path is a symlink, it will follow the link to the real path.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#hostpath";
          type = types.str;
        };
        "type" = mkOption {
          description = "type for HostPath Volume\nDefaults to \"\"\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#hostpath";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesImage" = {
      options = {
        "pullPolicy" = mkOption {
          description = "Policy for pulling OCI objects. Possible values are:\nAlways: the kubelet always attempts to pull the reference. Container creation will fail If the pull fails.\nNever: the kubelet never pulls the reference and only uses a local image or artifact. Container creation will fail if the reference isn't present.\nIfNotPresent: the kubelet pulls if the reference isn't already present on disk. Container creation will fail if the reference isn't present and the pull fails.\nDefaults to Always if :latest tag is specified, or IfNotPresent otherwise.";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "Required: Image or artifact reference to be used.\nBehaves in the same way as pod.spec.containers[*].image.\nPull secrets will be assembled in the same way as for the container image by looking up node credentials, SA image pull secrets, and pod spec image pull secrets.\nMore info: https://kubernetes.io/docs/concepts/containers/images\nThis field is optional to allow higher level config management to default or override\ncontainer images in workload controllers like Deployments and StatefulSets.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesIscsi" = {
      options = {
        "chapAuthDiscovery" = mkOption {
          description = "chapAuthDiscovery defines whether support iSCSI Discovery CHAP authentication";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "chapAuthSession defines whether support iSCSI Session CHAP authentication";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "fsType is the filesystem type of the volume that you want to mount.\nTip: Ensure that the filesystem type is supported by the host operating system.\nExamples: \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#iscsi";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "initiatorName is the custom iSCSI Initiator Name.\nIf initiatorName is specified with iscsiInterface simultaneously, new iSCSI interface\n<target portal>:<volume name> will be created for the connection.";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "iqn is the target iSCSI Qualified Name.";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "iscsiInterface is the interface Name that uses an iSCSI transport.\nDefaults to 'default' (tcp).";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "lun represents iSCSI Target Lun number.";
          type = types.int;
        };
        "portals" = mkOption {
          description = "portals is the iSCSI Target Portal List. The portal is either an IP or ip_addr:port if the port\nis other than default (typically TCP ports 860 and 3260).";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "readOnly here will force the ReadOnly setting in VolumeMounts.\nDefaults to false.";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "secretRef is the CHAP Secret for iSCSI target and initiator authentication";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "targetPortal is iSCSI Target Portal. The Portal is either an IP or ip_addr:port if the port\nis other than default (typically TCP ports 860 and 3260).";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesIscsiSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesNfs" = {
      options = {
        "path" = mkOption {
          description = "path that is exported by the NFS server.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#nfs";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly here will force the NFS export to be mounted with read-only permissions.\nDefaults to false.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#nfs";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "server is the hostname or IP address of the NFS server.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#nfs";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesPersistentVolumeClaim" = {
      options = {
        "claimName" = mkOption {
          description = "claimName is the name of a PersistentVolumeClaim in the same namespace as the pod using this volume.\nMore info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#persistentvolumeclaims";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly Will force the ReadOnly setting in VolumeMounts.\nDefault false.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesPhotonPersistentDisk" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "pdID is the ID that identifies Photon Controller persistent disk";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesPortworxVolume" = {
      options = {
        "fsType" = mkOption {
          description = "fSType represents the filesystem type to mount\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\". Implicitly inferred to be \"ext4\" if unspecified.";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "volumeID uniquely identifies a Portworx volume";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjected" = {
      options = {
        "defaultMode" = mkOption {
          description = "defaultMode are the mode bits used to set permissions on created files by default.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nDirectories within the path are not affected by this setting.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "sources is the list of volume projections. Each entry in this list\nhandles one source.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSources"));
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSources" = {
      options = {
        "clusterTrustBundle" = mkOption {
          description = "ClusterTrustBundle allows a pod to access the `.spec.trustBundle` field\nof ClusterTrustBundle objects in an auto-updating file.\n\nAlpha, gated by the ClusterTrustBundleProjection feature gate.\n\nClusterTrustBundle objects can either be selected by name, or by the\ncombination of signer name and a label selector.\n\nKubelet performs aggressive normalization of the PEM contents written\ninto the pod filesystem.  Esoteric PEM features such as inter-block\ncomments and block headers are stripped.  Certificates are deduplicated.\nThe ordering of certificates within the file is arbitrary, and Kubelet\nmay change the order over time.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesClusterTrustBundle");
        };
        "configMap" = mkOption {
          description = "configMap information about the configMap data to project";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesConfigMap");
        };
        "downwardAPI" = mkOption {
          description = "downwardAPI information about the downwardAPI data to project";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPI");
        };
        "secret" = mkOption {
          description = "secret information about the secret data to project";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesSecret");
        };
        "serviceAccountToken" = mkOption {
          description = "serviceAccountToken is information about the serviceAccountToken data to project";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesServiceAccountToken");
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesClusterTrustBundle" = {
      options = {
        "labelSelector" = mkOption {
          description = "Select all ClusterTrustBundles that match this label selector.  Only has\neffect if signerName is set.  Mutually-exclusive with name.  If unset,\ninterpreted as \"match nothing\".  If set but empty, interpreted as \"match\neverything\".";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesClusterTrustBundleLabelSelector");
        };
        "name" = mkOption {
          description = "Select a single ClusterTrustBundle by object name.  Mutually-exclusive\nwith signerName and labelSelector.";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "If true, don't block pod startup if the referenced ClusterTrustBundle(s)\naren't available.  If using name, then the named ClusterTrustBundle is\nallowed not to exist.  If using signerName, then the combination of\nsignerName and labelSelector is allowed to match zero\nClusterTrustBundles.";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "Relative path from the volume root to write the bundle.";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "Select all ClusterTrustBundles that match this signer name.\nMutually-exclusive with name.  The contents of all selected\nClusterTrustBundles will be unified and deduplicated.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesClusterTrustBundleLabelSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"));
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesConfigMap" = {
      options = {
        "items" = mkOption {
          description = "items if unspecified, each key-value pair in the Data field of the referenced\nConfigMap will be projected into the volume as a file whose name is the\nkey and content is the value. If specified, the listed keys will be\nprojected into the specified paths, and unlisted keys will not be\npresent. If a key is specified which is not present in the ConfigMap,\nthe volume setup will error unless it is marked optional. Paths must be\nrelative and may not contain the '..' path or start with '..'.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesConfigMapItems"));
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "optional specify whether the ConfigMap or its keys must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesConfigMapItems" = {
      options = {
        "key" = mkOption {
          description = "key is the key to project.";
          type = types.str;
        };
        "mode" = mkOption {
          description = "mode is Optional: mode bits used to set permissions on this file.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nIf not specified, the volume defaultMode will be used.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "path is the relative path of the file to map the key to.\nMay not be an absolute path.\nMay not contain the path element '..'.\nMay not start with the string '..'.";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPI" = {
      options = {
        "items" = mkOption {
          description = "Items is a list of DownwardAPIVolume file";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPIItems"));
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPIItems" = {
      options = {
        "fieldRef" = mkOption {
          description = "Required: Selects a field of the pod: only annotations, labels, name, namespace and uid are supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPIItemsFieldRef");
        };
        "mode" = mkOption {
          description = "Optional: mode bits used to set permissions on this file, must be an octal value\nbetween 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nIf not specified, the volume defaultMode will be used.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "Required: Path is  the relative path name of the file to be created. Must not be absolute or contain the '..' path. Must be utf-8 encoded. The first item of the relative path must not start with '..'";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "Selects a resource of the container: only resources limits and requests\n(limits.cpu, limits.memory, requests.cpu and requests.memory) are currently supported.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef");
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "Version of the schema the FieldPath is written in terms of, defaults to \"v1\".";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "Path of the field to select in the specified API version.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" = {
      options = {
        "containerName" = mkOption {
          description = "Container name: required for volumes, optional for env vars";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "Specifies the output format of the exposed resources, defaults to \"1\"";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "Required: resource to select";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesSecret" = {
      options = {
        "items" = mkOption {
          description = "items if unspecified, each key-value pair in the Data field of the referenced\nSecret will be projected into the volume as a file whose name is the\nkey and content is the value. If specified, the listed keys will be\nprojected into the specified paths, and unlisted keys will not be\npresent. If a key is specified which is not present in the Secret,\nthe volume setup will error unless it is marked optional. Paths must be\nrelative and may not contain the '..' path or start with '..'.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesSecretItems"));
        };
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "optional field specify whether the Secret or its key must be defined";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesSecretItems" = {
      options = {
        "key" = mkOption {
          description = "key is the key to project.";
          type = types.str;
        };
        "mode" = mkOption {
          description = "mode is Optional: mode bits used to set permissions on this file.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nIf not specified, the volume defaultMode will be used.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "path is the relative path of the file to map the key to.\nMay not be an absolute path.\nMay not contain the path element '..'.\nMay not start with the string '..'.";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesProjectedSourcesServiceAccountToken" = {
      options = {
        "audience" = mkOption {
          description = "audience is the intended audience of the token. A recipient of a token\nmust identify itself with an identifier specified in the audience of the\ntoken, and otherwise should reject the token. The audience defaults to the\nidentifier of the apiserver.";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "expirationSeconds is the requested duration of validity of the service\naccount token. As the token approaches expiration, the kubelet volume\nplugin will proactively rotate the service account token. The kubelet will\nstart trying to rotate the token if the token is older than 80 percent of\nits time to live or if the token is older than 24 hours.Defaults to 1 hour\nand must be at least 10 minutes.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "path is the path relative to the mount point of the file to project the\ntoken into.";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesQuobyte" = {
      options = {
        "group" = mkOption {
          description = "group to map volume access to\nDefault is no group";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly here will force the Quobyte volume to be mounted with read-only permissions.\nDefaults to false.";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "registry represents a single or multiple Quobyte Registry services\nspecified as a string as host:port pair (multiple entries are separated with commas)\nwhich acts as the central registry for volumes";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "tenant owning the given Quobyte volume in the Backend\nUsed with dynamically provisioned Quobyte volumes, value is set by the plugin";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "user to map volume access to\nDefaults to serivceaccount user";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "volume is a string that references an already created Quobyte volume by name.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesRbd" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type of the volume that you want to mount.\nTip: Ensure that the filesystem type is supported by the host operating system.\nExamples: \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#rbd";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "image is the rados image name.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "keyring is the path to key ring for RBDUser.\nDefault is /etc/ceph/keyring.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "monitors is a collection of Ceph monitors.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "pool is the rados pool name.\nDefault is rbd.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly here will force the ReadOnly setting in VolumeMounts.\nDefaults to false.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "secretRef is name of the authentication secret for RBDUser. If provided\noverrides keyring.\nDefault is nil.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "user is the rados user name.\nDefault is admin.\nMore info: https://examples.k8s.io/volumes/rbd/README.md#how-to-use-it";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesRbdSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesScaleIO" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\".\nDefault is \"xfs\".";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "gateway is the host address of the ScaleIO API Gateway.";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "protectionDomain is the name of the ScaleIO Protection Domain for the configured storage.";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly Defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "secretRef references to the secret for ScaleIO user and other\nsensitive information. If this is not provided, Login operation will fail.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "sslEnabled Flag enable/disable SSL communication with Gateway, default false";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "storageMode indicates whether the storage for a volume should be ThickProvisioned or ThinProvisioned.\nDefault is ThinProvisioned.";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "storagePool is the ScaleIO Storage Pool associated with the protection domain.";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "system is the name of the storage system as configured in ScaleIO.";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "volumeName is the name of a volume already created in the ScaleIO system\nthat is associated with this volume source.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesScaleIOSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesSecret" = {
      options = {
        "defaultMode" = mkOption {
          description = "defaultMode is Optional: mode bits used to set permissions on created files by default.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values\nfor mode bits. Defaults to 0644.\nDirectories within the path are not affected by this setting.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "items If unspecified, each key-value pair in the Data field of the referenced\nSecret will be projected into the volume as a file whose name is the\nkey and content is the value. If specified, the listed keys will be\nprojected into the specified paths, and unlisted keys will not be\npresent. If a key is specified which is not present in the Secret,\nthe volume setup will error unless it is marked optional. Paths must be\nrelative and may not contain the '..' path or start with '..'.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesSecretItems"));
        };
        "optional" = mkOption {
          description = "optional field specify whether the Secret or its keys must be defined";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "secretName is the name of the secret in the pod's namespace to use.\nMore info: https://kubernetes.io/docs/concepts/storage/volumes#secret";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesSecretItems" = {
      options = {
        "key" = mkOption {
          description = "key is the key to project.";
          type = types.str;
        };
        "mode" = mkOption {
          description = "mode is Optional: mode bits used to set permissions on this file.\nMust be an octal value between 0000 and 0777 or a decimal value between 0 and 511.\nYAML accepts both octal and decimal values, JSON requires decimal values for mode bits.\nIf not specified, the volume defaultMode will be used.\nThis might be in conflict with other options that affect the file\nmode, like fsGroup, and the result can be other mode bits set.";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "path is the relative path of the file to map the key to.\nMay not be an absolute path.\nMay not contain the path element '..'.\nMay not start with the string '..'.";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesStorageos" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is the filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "readOnly defaults to false (read/write). ReadOnly here will force\nthe ReadOnly setting in VolumeMounts.";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "secretRef specifies the secret to use for obtaining the StorageOS API\ncredentials.  If not specified, default values will be attempted.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesStorageosSecretRef");
        };
        "volumeName" = mkOption {
          description = "volumeName is the human-readable name of the StorageOS volume.  Volume\nnames are only unique within a namespace.";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "volumeNamespace specifies the scope of the volume within StorageOS.  If no\nnamespace is specified then the Pod's namespace will be used.  This allows the\nKubernetes name scoping to be mirrored within StorageOS for tighter integration.\nSet VolumeName to any name to override the default behaviour.\nSet to \"default\" if you are not using namespaces within StorageOS.\nNamespaces that do not pre-exist within StorageOS will be created.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesStorageosSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecDeploymentTemplateSpecTemplateSpecVolumesVsphereVolume" = {
      options = {
        "fsType" = mkOption {
          description = "fsType is filesystem type to mount.\nMust be a filesystem type supported by the host operating system.\nEx. \"ext4\", \"xfs\", \"ntfs\". Implicitly inferred to be \"ext4\" if unspecified.";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "storagePolicyID is the storage Policy Based Management (SPBM) profile ID associated with the StoragePolicyName.";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "storagePolicyName is the storage Policy Based Management (SPBM) profile name.";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "volumePath is the path that identifies vSphere volume vmdk";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecServiceAccountTemplate" = {
      options = {
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfigSpecServiceTemplate" = {
      options = {
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.Function" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "FunctionSpec specifies the configuration of a Function.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionSpec");
        };
        "status" = mkOption {
          description = "FunctionStatus represents the observed state of a Function.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevision" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "FunctionRevisionSpec specifies configuration for a FunctionRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionRevisionSpec");
        };
        "status" = mkOption {
          description = "FunctionRevisionStatus represents the observed state of a FunctionRevision.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionRevisionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "controllerConfigRef" = mkOption {
          description = "ControllerConfigRef references a ControllerConfig resource that will be\nused to configure the packaged controller Deployment.\nDeprecated: Use RuntimeConfigReference instead.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionRevisionSpecControllerConfigRef");
        };
        "desiredState" = mkOption {
          description = "DesiredState of the PackageRevision. Can be either Active or Inactive.";
          type = types.str;
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "image" = mkOption {
          description = "Package image used by install Pod to extract package contents.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package. It is also\napplied to any images pulled for the package, such as a provider's\ncontroller image.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be\nused to fetch packages from private registries. They are also applied to\nany images pulled for the package, such as a provider's controller image.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.FunctionRevisionSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revision" = mkOption {
          description = "Revision number. Indicates when the revision will be garbage collected\nbased on the parent's RevisionHistoryLimit.";
          type = types.int;
        };
        "runtimeConfigRef" = mkOption {
          description = "RuntimeConfigRef references a RuntimeConfig resource that will be used\nto configure the package runtime.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionRevisionSpecRuntimeConfigRef");
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "tlsClientSecretName" = mkOption {
          description = "TLSClientSecretName is the name of the TLS Secret that stores client\ncertificates of the Provider.";
          type = types.nullOr types.str;
        };
        "tlsServerSecretName" = mkOption {
          description = "TLSServerSecretName is the name of the TLS Secret that stores server\ncertificates of the Provider.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "controllerConfigRef" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "runtimeConfigRef" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
        "tlsClientSecretName" = mkOverride 1002 null;
        "tlsServerSecretName" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionSpecControllerConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the ControllerConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionSpecRuntimeConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the RuntimeConfig.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.FunctionRevisionStatusConditions"));
        };
        "endpoint" = mkOption {
          description = "Endpoint is the gRPC endpoint where Crossplane will send\nRunFunctionRequests.";
          type = types.nullOr types.str;
        };
        "foundDependencies" = mkOption {
          description = "Dependency information.";
          type = types.nullOr types.int;
        };
        "installedDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "invalidDependencies" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "objectRefs" = mkOption {
          description = "References to objects owned by PackageRevision.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.FunctionRevisionStatusObjectRefs" "name" []);
          apply = attrsToList;
        };
        "permissionRequests" = mkOption {
          description = "PermissionRequests made by this package. The package declares that its\ncontroller needs these permissions to run. The RBAC manager is\nresponsible for granting them.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.FunctionRevisionStatusPermissionRequests"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "endpoint" = mkOverride 1002 null;
        "foundDependencies" = mkOverride 1002 null;
        "installedDependencies" = mkOverride 1002 null;
        "invalidDependencies" = mkOverride 1002 null;
        "objectRefs" = mkOverride 1002 null;
        "permissionRequests" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionStatusObjectRefs" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the referenced object.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referenced object.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referenced object.";
          type = types.str;
        };
        "uid" = mkOption {
          description = "UID of the referenced object.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "uid" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionRevisionStatusPermissionRequests" = {
      options = {
        "apiGroups" = mkOption {
          description = "APIGroups is the name of the APIGroup that contains the resources.  If multiple API groups are specified, any action requested against one of\nthe enumerated resources in any API group will be allowed. \"\" represents the core API group and \"*\" represents all API groups.";
          type = types.nullOr (types.listOf types.str);
        };
        "nonResourceURLs" = mkOption {
          description = "NonResourceURLs is a set of partial urls that a user should have access to.  *s are allowed, but only as the full, final step in the path\nSince non-resource URLs are not namespaced, this field is only applicable for ClusterRoles referenced from a ClusterRoleBinding.\nRules can either apply to API resources (such as \"pods\" or \"secrets\") or non-resource URL paths (such as \"/api\"),  but not both.";
          type = types.nullOr (types.listOf types.str);
        };
        "resourceNames" = mkOption {
          description = "ResourceNames is an optional white list of names that the rule applies to.  An empty set means that everything is allowed.";
          type = types.nullOr (types.listOf types.str);
        };
        "resources" = mkOption {
          description = "Resources is a list of resources this rule applies to. '*' represents all resources.";
          type = types.nullOr (types.listOf types.str);
        };
        "verbs" = mkOption {
          description = "Verbs is a list of Verbs that apply to ALL the ResourceKinds contained in this rule. '*' represents all verbs.";
          type = types.listOf types.str;
        };
      };

      config = {
        "apiGroups" = mkOverride 1002 null;
        "nonResourceURLs" = mkOverride 1002 null;
        "resourceNames" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionSpec" = {
      options = {
        "commonLabels" = mkOption {
          description = "Map of string keys and values that can be used to organize and categorize\n(scope and select) objects. May match selectors of replication controllers\nand services.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/";
          type = types.nullOr (types.attrsOf types.str);
        };
        "controllerConfigRef" = mkOption {
          description = "ControllerConfigRef references a ControllerConfig resource that will be\nused to configure the packaged controller Deployment.\nDeprecated: Use RuntimeConfigReference instead.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionSpecControllerConfigRef");
        };
        "ignoreCrossplaneConstraints" = mkOption {
          description = "IgnoreCrossplaneConstraints indicates to the package manager whether to\nhonor Crossplane version constrains specified by the package.\nDefault is false.";
          type = types.nullOr types.bool;
        };
        "package" = mkOption {
          description = "Package is the name of the package that is being requested.";
          type = types.str;
        };
        "packagePullPolicy" = mkOption {
          description = "PackagePullPolicy defines the pull policy for the package.\nDefault is IfNotPresent.";
          type = types.nullOr types.str;
        };
        "packagePullSecrets" = mkOption {
          description = "PackagePullSecrets are named secrets in the same namespace that can be used\nto fetch packages from private registries.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.FunctionSpecPackagePullSecrets" "name" []);
          apply = attrsToList;
        };
        "revisionActivationPolicy" = mkOption {
          description = "RevisionActivationPolicy specifies how the package controller should\nupdate from one revision to the next. Options are Automatic or Manual.\nDefault is Automatic.";
          type = types.nullOr types.str;
        };
        "revisionHistoryLimit" = mkOption {
          description = "RevisionHistoryLimit dictates how the package controller cleans up old\ninactive package revisions.\nDefaults to 1. Can be disabled by explicitly setting to 0.";
          type = types.nullOr types.int;
        };
        "runtimeConfigRef" = mkOption {
          description = "RuntimeConfigRef references a RuntimeConfig resource that will be used\nto configure the package runtime.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.FunctionSpecRuntimeConfigRef");
        };
        "skipDependencyResolution" = mkOption {
          description = "SkipDependencyResolution indicates to the package manager whether to skip\nresolving dependencies for a package. Setting this value to true may have\nunintended consequences.\nDefault is false.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonLabels" = mkOverride 1002 null;
        "controllerConfigRef" = mkOverride 1002 null;
        "ignoreCrossplaneConstraints" = mkOverride 1002 null;
        "packagePullPolicy" = mkOverride 1002 null;
        "packagePullSecrets" = mkOverride 1002 null;
        "revisionActivationPolicy" = mkOverride 1002 null;
        "revisionHistoryLimit" = mkOverride 1002 null;
        "runtimeConfigRef" = mkOverride 1002 null;
        "skipDependencyResolution" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionSpecControllerConfigRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the ControllerConfig.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.FunctionSpecPackagePullSecrets" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionSpecRuntimeConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "API version of the referent.";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referent.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name of the RuntimeConfig.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.FunctionStatusConditions"));
        };
        "currentIdentifier" = mkOption {
          description = "CurrentIdentifier is the most recent package source that was used to\nproduce a revision. The package manager uses this field to determine\nwhether to check for package updates for a given source when\npackagePullPolicy is set to IfNotPresent. Manually removing this field\nwill cause the package manager to check that the current revision is\ncorrect for the given package source.";
          type = types.nullOr types.str;
        };
        "currentRevision" = mkOption {
          description = "CurrentRevision is the name of the current package revision. It will\nreflect the most up to date revision, whether it has been activated or\nnot.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "currentIdentifier" = mkOverride 1002 null;
        "currentRevision" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.FunctionStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfig" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "ImageConfigSpec contains the configuration for matching images.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpec" = {
      options = {
        "matchImages" = mkOption {
          description = "MatchImages is a list of image matching rules that should be satisfied.";
          type = types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecMatchImages");
        };
        "registry" = mkOption {
          description = "Registry is the configuration for the registry.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecRegistry");
        };
        "verification" = mkOption {
          description = "Verification contains the configuration for verifying the image.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecVerification");
        };
      };

      config = {
        "registry" = mkOverride 1002 null;
        "verification" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecMatchImages" = {
      options = {
        "prefix" = mkOption {
          description = "Prefix is the prefix that should be matched.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type is the type of match.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecRegistry" = {
      options = {
        "authentication" = mkOption {
          description = "Authentication is the authentication information for the registry.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecRegistryAuthentication");
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecRegistryAuthentication" = {
      options = {
        "pullSecretRef" = mkOption {
          description = "PullSecretRef is a reference to a secret that contains the credentials for\nthe registry.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecRegistryAuthenticationPullSecretRef";
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecRegistryAuthenticationPullSecretRef" = {
      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerification" = {
      options = {
        "cosign" = mkOption {
          description = "Cosign is the configuration for verifying the image using cosign.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosign");
        };
        "provider" = mkOption {
          description = "Provider is the provider that should be used to verify the image.";
          type = types.str;
        };
      };

      config = {
        "cosign" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosign" = {
      options = {
        "authorities" = mkOption {
          description = "Authorities defines the rules for discovering and validating signatures.";
          type = coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthorities" "name" [];
          apply = attrsToList;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthorities" = {
      options = {
        "attestations" = mkOption {
          description = "Attestations is a list of individual attestations for this authority,\nonce the signature for this authority has been verified.";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesAttestations" "name" []);
          apply = attrsToList;
        };
        "key" = mkOption {
          description = "Key defines the type of key to validate the image.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKey");
        };
        "keyless" = mkOption {
          description = "Keyless sets the configuration to verify the authority against a Fulcio\ninstance.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKeyless");
        };
        "name" = mkOption {
          description = "Name is the name for this authority.";
          type = types.str;
        };
      };

      config = {
        "attestations" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "keyless" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesAttestations" = {
      options = {
        "name" = mkOption {
          description = "Name of the attestation.";
          type = types.str;
        };
        "predicateType" = mkOption {
          description = "PredicateType defines which predicate type to verify. Matches cosign\nverify-attestation options.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKey" = {
      options = {
        "hashAlgorithm" = mkOption {
          description = "HashAlgorithm always defaults to sha256 if the algorithm hasn't been explicitly set";
          type = types.str;
        };
        "secretRef" = mkOption {
          description = "SecretRef sets a reference to a secret with the key.";
          type = submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKeySecretRef";
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKeySecretRef" = {
      options = {
        "key" = mkOption {
          description = "The key to select.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the secret.";
          type = types.str;
        };
      };

      config = {};
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKeyless" = {
      options = {
        "identities" = mkOption {
          description = "Identities sets a list of identities.";
          type = types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKeylessIdentities");
        };
        "insecureIgnoreSCT" = mkOption {
          description = "InsecureIgnoreSCT omits verifying if a certificate contains an embedded SCT";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "insecureIgnoreSCT" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.ImageConfigSpecVerificationCosignAuthoritiesKeylessIdentities" = {
      options = {
        "issuer" = mkOption {
          description = "Issuer defines the issuer for this identity.";
          type = types.nullOr types.str;
        };
        "issuerRegExp" = mkOption {
          description = "IssuerRegExp specifies a regular expression to match the issuer for this identity.\nThis has precedence over the Issuer field.";
          type = types.nullOr types.str;
        };
        "subject" = mkOption {
          description = "Subject defines the subject for this identity.";
          type = types.nullOr types.str;
        };
        "subjectRegExp" = mkOption {
          description = "SubjectRegExp specifies a regular expression to match the subject for this identity.\nThis has precedence over the Subject field.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "issuer" = mkOverride 1002 null;
        "issuerRegExp" = mkOverride 1002 null;
        "subject" = mkOverride 1002 null;
        "subjectRegExp" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.Lock" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "packages" = mkOption {
          description = "";
          type = types.nullOr (coerceAttrsOfSubmodulesToListByKey "pkg.crossplane.io.v1beta1.LockPackages" "name" []);
          apply = attrsToList;
        };
        "status" = mkOption {
          description = "Status of the Lock.";
          type = types.nullOr (submoduleOf "pkg.crossplane.io.v1beta1.LockStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "packages" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.LockPackages" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the package.";
          type = types.nullOr types.str;
        };
        "dependencies" = mkOption {
          description = "Dependencies are the list of dependencies of this package. The order of\nthe dependencies will dictate the order in which they are resolved.";
          type = types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.LockPackagesDependencies");
        };
        "kind" = mkOption {
          description = "Kind of the package (not the kind of the package revision).";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name corresponds to the name of the package revision for this package.";
          type = types.str;
        };
        "source" = mkOption {
          description = "Source is the OCI image name without a tag or digest.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type is the type of package.\nDeprecated: Specify an apiVersion and kind instead.";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "Version is the tag or digest of the OCI image.";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.LockPackagesDependencies" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the package.";
          type = types.nullOr types.str;
        };
        "constraints" = mkOption {
          description = "Constraints is a valid semver range or a digest, which will be used to select a valid\ndependency version.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the package (not the kind of the package revision).";
          type = types.nullOr types.str;
        };
        "package" = mkOption {
          description = "Package is the OCI image name without a tag or digest.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type is the type of package. Can be either Configuration or Provider.\nDeprecated: Specify an apiVersion and kind instead.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.LockStatus" = {
      options = {
        "conditions" = mkOption {
          description = "Conditions of the resource.";
          type = types.nullOr (types.listOf (submoduleOf "pkg.crossplane.io.v1beta1.LockStatusConditions"));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };
    };
    "pkg.crossplane.io.v1beta1.LockStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "LastTransitionTime is the last time this condition transitioned from one\nstatus to another.";
          type = types.str;
        };
        "message" = mkOption {
          description = "A Message containing details about this condition's last transition from\none status to another, if any.";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "A Reason for this condition's last transition from one status to another.";
          type = types.str;
        };
        "status" = mkOption {
          description = "Status of this condition; is it currently True, False, or Unknown?";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of this condition. At most one of each condition type may apply to\na resource at any point in time.";
          type = types.str;
        };
      };

      config = {
        "message" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };
    };
    "secrets.crossplane.io.v1alpha1.StoreConfig" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "A StoreConfigSpec defines the desired state of a StoreConfig.";
          type = submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
      };
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpec" = {
      options = {
        "defaultScope" = mkOption {
          description = "DefaultScope used for scoping secrets for \"cluster-scoped\" resources.\nIf store type is \"Kubernetes\", this would mean the default namespace to\nstore connection secrets for cluster scoped resources.\nIn case of \"Vault\", this would be used as the default parent path.\nTypically, should be set as Crossplane installation namespace.";
          type = types.str;
        };
        "kubernetes" = mkOption {
          description = "Kubernetes configures a Kubernetes secret store.\nIf the \"type\" is \"Kubernetes\" but no config provided, in cluster config\nwill be used.";
          type = types.nullOr (submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetes");
        };
        "plugin" = mkOption {
          description = "Plugin configures External secret store as a plugin.";
          type = types.nullOr (submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecPlugin");
        };
        "type" = mkOption {
          description = "Type configures which secret store to be used. Only the configuration\nblock for this store will be used and others will be ignored if provided.\nDefault is Kubernetes.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "kubernetes" = mkOverride 1002 null;
        "plugin" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetes" = {
      options = {
        "auth" = mkOption {
          description = "Credentials used to connect to the Kubernetes API.";
          type = submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuth";
        };
      };

      config = {};
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuth" = {
      options = {
        "env" = mkOption {
          description = "Env is a reference to an environment variable that contains credentials\nthat must be used to connect to the provider.";
          type = types.nullOr (submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuthEnv");
        };
        "fs" = mkOption {
          description = "Fs is a reference to a filesystem location that contains credentials that\nmust be used to connect to the provider.";
          type = types.nullOr (submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuthFs");
        };
        "secretRef" = mkOption {
          description = "A SecretRef is a reference to a secret key that contains the credentials\nthat must be used to connect to the provider.";
          type = types.nullOr (submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuthSecretRef");
        };
        "source" = mkOption {
          description = "Source of the credentials.";
          type = types.str;
        };
      };

      config = {
        "env" = mkOverride 1002 null;
        "fs" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuthEnv" = {
      options = {
        "name" = mkOption {
          description = "Name is the name of an environment variable.";
          type = types.str;
        };
      };

      config = {};
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuthFs" = {
      options = {
        "path" = mkOption {
          description = "Path is a filesystem path.";
          type = types.str;
        };
      };

      config = {};
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecKubernetesAuthSecretRef" = {
      options = {
        "key" = mkOption {
          description = "The key to select.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace of the secret.";
          type = types.str;
        };
      };

      config = {};
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecPlugin" = {
      options = {
        "configRef" = mkOption {
          description = "ConfigRef contains store config reference info.";
          type = types.nullOr (submoduleOf "secrets.crossplane.io.v1alpha1.StoreConfigSpecPluginConfigRef");
        };
        "endpoint" = mkOption {
          description = "Endpoint is the endpoint of the gRPC server.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "configRef" = mkOverride 1002 null;
        "endpoint" = mkOverride 1002 null;
      };
    };
    "secrets.crossplane.io.v1alpha1.StoreConfigSpecPluginConfigRef" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion of the referenced config.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind of the referenced config.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name of the referenced config.";
          type = types.str;
        };
      };

      config = {};
    };
  };
in {
  # all resource versions
  options = {
    resources =
      {
        "apiextensions.crossplane.io"."v1"."CompositeResourceDefinition" = mkOption {
          description = "A CompositeResourceDefinition defines the schema for a new custom Kubernetes\nAPI.\n\nRead the Crossplane documentation for\n[more information about CustomResourceDefinitions](https://docs.crossplane.io/latest/concepts/composite-resource-definitions).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1.CompositeResourceDefinition" "compositeresourcedefinitions" "CompositeResourceDefinition" "apiextensions.crossplane.io" "v1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1"."Composition" = mkOption {
          description = "A Composition defines a collection of managed resources or functions that\nCrossplane uses to create and manage new composite resources.\n\nRead the Crossplane documentation for\n[more information about Compositions](https://docs.crossplane.io/latest/concepts/compositions).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1.Composition" "compositions" "Composition" "apiextensions.crossplane.io" "v1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1"."CompositionRevision" = mkOption {
          description = "A CompositionRevision represents a revision of a Composition. Crossplane\ncreates new revisions when there are changes to the Composition.\n\nCrossplane creates and manages CompositionRevisions. Don't directly edit\nCompositionRevisions.";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1.CompositionRevision" "compositionrevisions" "CompositionRevision" "apiextensions.crossplane.io" "v1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1alpha1"."EnvironmentConfig" = mkOption {
          description = "An EnvironmentConfig contains user-defined unstructured values for\nuse in a Composition.\n\nRead the Crossplane documentation for\n[more information about EnvironmentConfigs](https://docs.crossplane.io/latest/concepts/environment-configs).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1alpha1.EnvironmentConfig" "environmentconfigs" "EnvironmentConfig" "apiextensions.crossplane.io" "v1alpha1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1alpha1"."Usage" = mkOption {
          description = "A Usage defines a deletion blocking relationship between two resources.\n\nUsages prevent accidental deletion of a single resource or deletion of\nresources with dependent resources.\n\nRead the Crossplane documentation for\n[more information about Compositions](https://docs.crossplane.io/latest/concepts/usages).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1alpha1.Usage" "usages" "Usage" "apiextensions.crossplane.io" "v1alpha1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1beta1"."CompositionRevision" = mkOption {
          description = "A CompositionRevision represents a revision of a Composition. Crossplane\ncreates new revisions when there are changes to the Composition.\n\nCrossplane creates and manages CompositionRevisions. Don't directly edit\nCompositionRevisions.";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1beta1.CompositionRevision" "compositionrevisions" "CompositionRevision" "apiextensions.crossplane.io" "v1beta1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1beta1"."EnvironmentConfig" = mkOption {
          description = "An EnvironmentConfig contains user-defined unstructured values for\nuse in a Composition.\n\nRead the Crossplane documentation for\n[more information about EnvironmentConfigs](https://docs.crossplane.io/latest/concepts/environment-configs).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1beta1.EnvironmentConfig" "environmentconfigs" "EnvironmentConfig" "apiextensions.crossplane.io" "v1beta1");
          default = {};
        };
        "apiextensions.crossplane.io"."v1beta1"."Usage" = mkOption {
          description = "A Usage defines a deletion blocking relationship between two resources.\n\nUsages prevent accidental deletion of a single resource or deletion of\nresources with dependent resources.\n\nRead the Crossplane documentation for\n[more information about Compositions](https://docs.crossplane.io/latest/concepts/usages).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1beta1.Usage" "usages" "Usage" "apiextensions.crossplane.io" "v1beta1");
          default = {};
        };
        "pkg.crossplane.io"."v1"."Configuration" = mkOption {
          description = "A Configuration installs an OCI compatible Crossplane package, extending\nCrossplane with support for new kinds of CompositeResourceDefinitions and\nCompositions.\n\nRead the Crossplane documentation for\n[more information about Configuration packages](https://docs.crossplane.io/latest/concepts/packages).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.Configuration" "configurations" "Configuration" "pkg.crossplane.io" "v1");
          default = {};
        };
        "pkg.crossplane.io"."v1"."ConfigurationRevision" = mkOption {
          description = "A ConfigurationRevision represents a revision of a Configuration. Crossplane\ncreates new revisions when there are changes to a Configuration.\n\nCrossplane creates and manages ConfigurationRevision. Don't directly edit\nConfigurationRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.ConfigurationRevision" "configurationrevisions" "ConfigurationRevision" "pkg.crossplane.io" "v1");
          default = {};
        };
        "pkg.crossplane.io"."v1"."Function" = mkOption {
          description = "A Function installs an OCI compatible Crossplane package, extending\nCrossplane with support for a new kind of composition function.\n\nRead the Crossplane documentation for\n[more information about Functions](https://docs.crossplane.io/latest/concepts/composition-functions).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.Function" "functions" "Function" "pkg.crossplane.io" "v1");
          default = {};
        };
        "pkg.crossplane.io"."v1"."FunctionRevision" = mkOption {
          description = "A FunctionRevision represents a revision of a Function. Crossplane\ncreates new revisions when there are changes to the Function.\n\nCrossplane creates and manages FunctionRevisions. Don't directly edit\nFunctionRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.FunctionRevision" "functionrevisions" "FunctionRevision" "pkg.crossplane.io" "v1");
          default = {};
        };
        "pkg.crossplane.io"."v1"."Provider" = mkOption {
          description = "A Provider installs an OCI compatible Crossplane package, extending\nCrossplane with support for new kinds of managed resources.\n\nRead the Crossplane documentation for\n[more information about Providers](https://docs.crossplane.io/latest/concepts/providers).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.Provider" "providers" "Provider" "pkg.crossplane.io" "v1");
          default = {};
        };
        "pkg.crossplane.io"."v1"."ProviderRevision" = mkOption {
          description = "A ProviderRevision represents a revision of a Provider. Crossplane\ncreates new revisions when there are changes to a Provider.\n\nCrossplane creates and manages ProviderRevisions. Don't directly edit\nProviderRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.ProviderRevision" "providerrevisions" "ProviderRevision" "pkg.crossplane.io" "v1");
          default = {};
        };
        "pkg.crossplane.io"."v1beta1"."DeploymentRuntimeConfig" = mkOption {
          description = "The DeploymentRuntimeConfig provides settings for the Kubernetes Deployment\nof a Provider or composition function package.\n\nRead the Crossplane documentation for\n[more information about DeploymentRuntimeConfigs](https://docs.crossplane.io/latest/concepts/providers/#runtime-configuration).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfig" "deploymentruntimeconfigs" "DeploymentRuntimeConfig" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "pkg.crossplane.io"."v1beta1"."Function" = mkOption {
          description = "A Function installs an OCI compatible Crossplane package, extending\nCrossplane with support for a new kind of composition function.\n\nRead the Crossplane documentation for\n[more information about Functions](https://docs.crossplane.io/latest/concepts/composition-functions).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.Function" "functions" "Function" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "pkg.crossplane.io"."v1beta1"."FunctionRevision" = mkOption {
          description = "A FunctionRevision represents a revision of a Function. Crossplane\ncreates new revisions when there are changes to the Function.\n\nCrossplane creates and manages FunctionRevisions. Don't directly edit\nFunctionRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.FunctionRevision" "functionrevisions" "FunctionRevision" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "pkg.crossplane.io"."v1beta1"."ImageConfig" = mkOption {
          description = "The ImageConfig resource is used to configure settings for package images.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.ImageConfig" "imageconfigs" "ImageConfig" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "pkg.crossplane.io"."v1beta1"."Lock" = mkOption {
          description = "Lock is the CRD type that tracks package dependencies.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.Lock" "locks" "Lock" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "secrets.crossplane.io"."v1alpha1"."StoreConfig" = mkOption {
          description = "A StoreConfig configures how Crossplane controllers should store connection\ndetails in an external secret store.";
          type = types.attrsOf (submoduleForDefinition "secrets.crossplane.io.v1alpha1.StoreConfig" "storeconfigs" "StoreConfig" "secrets.crossplane.io" "v1alpha1");
          default = {};
        };
      }
      // {
        "compositeResourceDefinitions" = mkOption {
          description = "A CompositeResourceDefinition defines the schema for a new custom Kubernetes\nAPI.\n\nRead the Crossplane documentation for\n[more information about CustomResourceDefinitions](https://docs.crossplane.io/latest/concepts/composite-resource-definitions).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1.CompositeResourceDefinition" "compositeresourcedefinitions" "CompositeResourceDefinition" "apiextensions.crossplane.io" "v1");
          default = {};
        };
        "compositions" = mkOption {
          description = "A Composition defines a collection of managed resources or functions that\nCrossplane uses to create and manage new composite resources.\n\nRead the Crossplane documentation for\n[more information about Compositions](https://docs.crossplane.io/latest/concepts/compositions).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1.Composition" "compositions" "Composition" "apiextensions.crossplane.io" "v1");
          default = {};
        };
        "compositionRevisions" = mkOption {
          description = "A CompositionRevision represents a revision of a Composition. Crossplane\ncreates new revisions when there are changes to the Composition.\n\nCrossplane creates and manages CompositionRevisions. Don't directly edit\nCompositionRevisions.";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1.CompositionRevision" "compositionrevisions" "CompositionRevision" "apiextensions.crossplane.io" "v1");
          default = {};
        };
        "configurations" = mkOption {
          description = "A Configuration installs an OCI compatible Crossplane package, extending\nCrossplane with support for new kinds of CompositeResourceDefinitions and\nCompositions.\n\nRead the Crossplane documentation for\n[more information about Configuration packages](https://docs.crossplane.io/latest/concepts/packages).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.Configuration" "configurations" "Configuration" "pkg.crossplane.io" "v1");
          default = {};
        };
        "configurationRevisions" = mkOption {
          description = "A ConfigurationRevision represents a revision of a Configuration. Crossplane\ncreates new revisions when there are changes to a Configuration.\n\nCrossplane creates and manages ConfigurationRevision. Don't directly edit\nConfigurationRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.ConfigurationRevision" "configurationrevisions" "ConfigurationRevision" "pkg.crossplane.io" "v1");
          default = {};
        };
        "deploymentRuntimeConfigs" = mkOption {
          description = "The DeploymentRuntimeConfig provides settings for the Kubernetes Deployment\nof a Provider or composition function package.\n\nRead the Crossplane documentation for\n[more information about DeploymentRuntimeConfigs](https://docs.crossplane.io/latest/concepts/providers/#runtime-configuration).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.DeploymentRuntimeConfig" "deploymentruntimeconfigs" "DeploymentRuntimeConfig" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "environmentConfigs" = mkOption {
          description = "An EnvironmentConfig contains user-defined unstructured values for\nuse in a Composition.\n\nRead the Crossplane documentation for\n[more information about EnvironmentConfigs](https://docs.crossplane.io/latest/concepts/environment-configs).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1beta1.EnvironmentConfig" "environmentconfigs" "EnvironmentConfig" "apiextensions.crossplane.io" "v1beta1");
          default = {};
        };
        "functions" = mkOption {
          description = "A Function installs an OCI compatible Crossplane package, extending\nCrossplane with support for a new kind of composition function.\n\nRead the Crossplane documentation for\n[more information about Functions](https://docs.crossplane.io/latest/concepts/composition-functions).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.Function" "functions" "Function" "pkg.crossplane.io" "v1");
          default = {};
        };
        "functionRevisions" = mkOption {
          description = "A FunctionRevision represents a revision of a Function. Crossplane\ncreates new revisions when there are changes to the Function.\n\nCrossplane creates and manages FunctionRevisions. Don't directly edit\nFunctionRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.FunctionRevision" "functionrevisions" "FunctionRevision" "pkg.crossplane.io" "v1");
          default = {};
        };
        "imageConfigs" = mkOption {
          description = "The ImageConfig resource is used to configure settings for package images.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.ImageConfig" "imageconfigs" "ImageConfig" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "locks" = mkOption {
          description = "Lock is the CRD type that tracks package dependencies.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1beta1.Lock" "locks" "Lock" "pkg.crossplane.io" "v1beta1");
          default = {};
        };
        "providers" = mkOption {
          description = "A Provider installs an OCI compatible Crossplane package, extending\nCrossplane with support for new kinds of managed resources.\n\nRead the Crossplane documentation for\n[more information about Providers](https://docs.crossplane.io/latest/concepts/providers).";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.Provider" "providers" "Provider" "pkg.crossplane.io" "v1");
          default = {};
        };
        "providerRevisions" = mkOption {
          description = "A ProviderRevision represents a revision of a Provider. Crossplane\ncreates new revisions when there are changes to a Provider.\n\nCrossplane creates and manages ProviderRevisions. Don't directly edit\nProviderRevisions.";
          type = types.attrsOf (submoduleForDefinition "pkg.crossplane.io.v1.ProviderRevision" "providerrevisions" "ProviderRevision" "pkg.crossplane.io" "v1");
          default = {};
        };
        "storeConfigs" = mkOption {
          description = "A StoreConfig configures how Crossplane controllers should store connection\ndetails in an external secret store.";
          type = types.attrsOf (submoduleForDefinition "secrets.crossplane.io.v1alpha1.StoreConfig" "storeconfigs" "StoreConfig" "secrets.crossplane.io" "v1alpha1");
          default = {};
        };
        "usages" = mkOption {
          description = "A Usage defines a deletion blocking relationship between two resources.\n\nUsages prevent accidental deletion of a single resource or deletion of\nresources with dependent resources.\n\nRead the Crossplane documentation for\n[more information about Compositions](https://docs.crossplane.io/latest/concepts/usages).";
          type = types.attrsOf (submoduleForDefinition "apiextensions.crossplane.io.v1beta1.Usage" "usages" "Usage" "apiextensions.crossplane.io" "v1beta1");
          default = {};
        };
      };
  };

  config = {
    # expose resource definitions
    inherit definitions;

    # register resource types
    types = [
      {
        name = "compositeresourcedefinitions";
        group = "apiextensions.crossplane.io";
        version = "v1";
        kind = "CompositeResourceDefinition";
        attrName = "compositeResourceDefinitions";
      }
      {
        name = "compositions";
        group = "apiextensions.crossplane.io";
        version = "v1";
        kind = "Composition";
        attrName = "compositions";
      }
      {
        name = "compositionrevisions";
        group = "apiextensions.crossplane.io";
        version = "v1";
        kind = "CompositionRevision";
        attrName = "compositionRevisions";
      }
      {
        name = "environmentconfigs";
        group = "apiextensions.crossplane.io";
        version = "v1alpha1";
        kind = "EnvironmentConfig";
        attrName = "environmentConfigs";
      }
      {
        name = "usages";
        group = "apiextensions.crossplane.io";
        version = "v1alpha1";
        kind = "Usage";
        attrName = "usages";
      }
      {
        name = "compositionrevisions";
        group = "apiextensions.crossplane.io";
        version = "v1beta1";
        kind = "CompositionRevision";
        attrName = "compositionRevisions";
      }
      {
        name = "environmentconfigs";
        group = "apiextensions.crossplane.io";
        version = "v1beta1";
        kind = "EnvironmentConfig";
        attrName = "environmentConfigs";
      }
      {
        name = "usages";
        group = "apiextensions.crossplane.io";
        version = "v1beta1";
        kind = "Usage";
        attrName = "usages";
      }
      {
        name = "configurations";
        group = "pkg.crossplane.io";
        version = "v1";
        kind = "Configuration";
        attrName = "configurations";
      }
      {
        name = "configurationrevisions";
        group = "pkg.crossplane.io";
        version = "v1";
        kind = "ConfigurationRevision";
        attrName = "configurationRevisions";
      }
      {
        name = "functions";
        group = "pkg.crossplane.io";
        version = "v1";
        kind = "Function";
        attrName = "functions";
      }
      {
        name = "functionrevisions";
        group = "pkg.crossplane.io";
        version = "v1";
        kind = "FunctionRevision";
        attrName = "functionRevisions";
      }
      {
        name = "providers";
        group = "pkg.crossplane.io";
        version = "v1";
        kind = "Provider";
        attrName = "providers";
      }
      {
        name = "providerrevisions";
        group = "pkg.crossplane.io";
        version = "v1";
        kind = "ProviderRevision";
        attrName = "providerRevisions";
      }
      {
        name = "deploymentruntimeconfigs";
        group = "pkg.crossplane.io";
        version = "v1beta1";
        kind = "DeploymentRuntimeConfig";
        attrName = "deploymentRuntimeConfigs";
      }
      {
        name = "functions";
        group = "pkg.crossplane.io";
        version = "v1beta1";
        kind = "Function";
        attrName = "functions";
      }
      {
        name = "functionrevisions";
        group = "pkg.crossplane.io";
        version = "v1beta1";
        kind = "FunctionRevision";
        attrName = "functionRevisions";
      }
      {
        name = "imageconfigs";
        group = "pkg.crossplane.io";
        version = "v1beta1";
        kind = "ImageConfig";
        attrName = "imageConfigs";
      }
      {
        name = "locks";
        group = "pkg.crossplane.io";
        version = "v1beta1";
        kind = "Lock";
        attrName = "locks";
      }
      {
        name = "storeconfigs";
        group = "secrets.crossplane.io";
        version = "v1alpha1";
        kind = "StoreConfig";
        attrName = "storeConfigs";
      }
    ];

    resources = {
      "apiextensions.crossplane.io"."v1"."CompositeResourceDefinition" =
        mkAliasDefinitions options.resources."compositeResourceDefinitions";
      "apiextensions.crossplane.io"."v1"."Composition" =
        mkAliasDefinitions options.resources."compositions";
      "apiextensions.crossplane.io"."v1"."CompositionRevision" =
        mkAliasDefinitions options.resources."compositionRevisions";
      "pkg.crossplane.io"."v1"."Configuration" =
        mkAliasDefinitions options.resources."configurations";
      "pkg.crossplane.io"."v1"."ConfigurationRevision" =
        mkAliasDefinitions options.resources."configurationRevisions";
      "pkg.crossplane.io"."v1beta1"."DeploymentRuntimeConfig" =
        mkAliasDefinitions options.resources."deploymentRuntimeConfigs";
      "apiextensions.crossplane.io"."v1beta1"."EnvironmentConfig" =
        mkAliasDefinitions options.resources."environmentConfigs";
      "pkg.crossplane.io"."v1"."Function" =
        mkAliasDefinitions options.resources."functions";
      "pkg.crossplane.io"."v1"."FunctionRevision" =
        mkAliasDefinitions options.resources."functionRevisions";
      "pkg.crossplane.io"."v1beta1"."ImageConfig" =
        mkAliasDefinitions options.resources."imageConfigs";
      "pkg.crossplane.io"."v1beta1"."Lock" =
        mkAliasDefinitions options.resources."locks";
      "pkg.crossplane.io"."v1"."Provider" =
        mkAliasDefinitions options.resources."providers";
      "pkg.crossplane.io"."v1"."ProviderRevision" =
        mkAliasDefinitions options.resources."providerRevisions";
      "secrets.crossplane.io"."v1alpha1"."StoreConfig" =
        mkAliasDefinitions options.resources."storeConfigs";
      "apiextensions.crossplane.io"."v1beta1"."Usage" =
        mkAliasDefinitions options.resources."usages";
    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [];
  };
}

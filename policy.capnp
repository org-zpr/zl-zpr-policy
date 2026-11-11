@0xe6944af362745a7d;

struct PolicyContainer {
  # Compiler information
  zplcVerMajor @0 :UInt32;
  zplcVerMinor @1 :UInt32;
  zplcVerPatch @2 :UInt32;

  policy    @3 :Data; # capnp encoded 'Policy'
  signature @4 :Data; # signature over 'policy' and 'source'
}

struct Policy {
  created         @0 :Text; # timestamp
  version         @1 :UInt64;
  metadata        @2 :Text;
  comPolicies     @3 :List(CPolicy);
  keys            @4 :List(KeyMaterial);
  joinPolicies    @5 :List(JPolicy);
  topology        @6 :List(Peering);
  trustedServices @7 :List(TrustedService);
  transitNodes    @8 :List(Text);  # node identifiers (same convention as Peering.nodeA: the
                                   # node's ZPR address) that may carry traffic between other
                                   # nodes. A node not listed is NOT transit-capable (fail
                                   # closed). Unset or empty = no node is transit-capable.
}

# "CPolicy" is a Communications Policy.
struct CPolicy {
  id           @0 :Text;
  serviceId    @1 :Text;
  zpl          @2 :Text;
  allow        @3 :Bool;
  scope        @4 :List(Scope);
  clientConds  @5 :List(AttrExpr);
  serviceConds @6 :List(AttrExpr);
  signal       @7 :Signal; # Don't need an is_signal because capnp has a has_signal func to see if this field is set
  linkConds    @8 :List(AttrExpr); # conditions each link on the path must satisfy
}

enum ScopeFlag {
  noFlag           @0;
  udpOneWay        @1;
  icmpRequestRepl  @2;
}

struct Scope {
  protocol @0 :UInt8;
  flag     @1 :ScopeFlag;
  union {
    port :group {
      portNum @2 :UInt16;
    }
    portRange :group {
        low   @3 :UInt16;
        high  @4 :UInt16;
    }
  }
}

# "JPolicy" is a join policy - who can join the network and what happens when they do.
struct JPolicy {
  match    @0 :List(AttrExpr); # all these attributes must match
  provides @1 :List(Service);
  flags    @2 :List(JoinFlag);
}

# A service offered on the network.
struct Service {
  id         @0 :Text;
  endpoints  @1 :List(Scope);
  kind :union {
    regular  @2 :Void;
    trusted  @3 :Text;  # takes an api name
    auth     @4 :Void;
    visa     @5 :Void;
    builtin  @6 :Void;
  }
}

# Additional details for Trusted Services
struct TrustedService {
  serviceId         @0 :Text; # Copied from Service.id
  expirationSeconds @1 :UInt32;
  returnsAttrs      @2 :List(AttrMapping);
  identityAttrs     @3 :List(Text);
  oidc              @4 :OidcConfig;   # populated only when Service.kind.trusted == "oidc"
  attrQuery         @5 :AttrQueryConfig;   # populated only when Service.kind.trusted == "zpr-attr/1"
}

# Configuration for an `api = "oidc"` trusted service. The visa service performs
# no OIDC discovery: everything it needs is pinned here and signed with the policy.
struct OidcConfig {
  issuer             @0 :Text;        # e.g. https://accounts.google.com
  jwksUri            @1 :Text;        # pinned; e.g. https://www.googleapis.com/oauth2/v3/certs
  clientId           @2 :Text;
  clientSecret       @3 :Text;        # optional; NOT a secret for public clients (RFC 8252 s8.5); "" = none
  scopes             @4 :List(Text);  # e.g. ["openid","email","profile"]
  allowedDomains     @5 :List(Text);  # matched against the `hd` claim; ["*"] = any account (explicit opt-in)
  maxAuthAgeSeconds  @6 :UInt32;      # 0 = unlimited
  allowOfflineAccess @7 :Bool;
  seedJwks           @8 :Text;        # JSON JWKS document for cold start
  jwksProxyService   @9 :Text;        # fabric service id of the CONNECT proxy; "" = direct egress
}

# Configuration for an `api = "zpr-attr/1"` attribute service. The bearer token the
# visa service presents is deliberately NOT here: policy is signed and distributed.
struct AttrQueryConfig {
  url            @0 :Text;    # https base URL; the visa service appends /query and /schema
  caCertPem      @1 :Text;    # PEM certificate block(s) to trust for this service; "" = system roots
  timeoutSeconds @2 :UInt32;  # whole-request timeout; compiler defaults 5, caps 30
}

# Directly maps to the ZPLC "returns_attributes" mapping
struct AttrMapping {
  serviceAttrKey @0 :Text;  # what the service calls the attribute
  zprAttrSpec    @1 :Text;  # what ZPR calls the attribute
}

# Two node peers form a link. Bi-directional and symmetric.
#
# Either substrate field may be left unset (has_nodeXSubstrate() == false): that node has
# no substrate address in policy and reports its own when it authenticates
# (zpr-core#1381). Both ends may be unset, e.g. a link between two endpoint Zodes.
# Readers must check has_*() and must not treat an unset NetAddr as an address; writers
# leave the field unset rather than writing an empty hostname or port 0.
struct Peering {
  linkId         @0 :Text;           # identifier for the link (for logging, debugging)
  nodeA          @1 :Text;           # node identifier (by convention its ZPR address)
  nodeASubstrate @2 :NetAddr;        # unset = reported by the node at run time
  nodeB          @3 :Text;           # node identifier (by convention its ZPR address)
  nodeBSubstrate @4 :NetAddr;        # unset = reported by the node at run time
  attrs          @5 :List(AttrExpr); # link attributes
}


struct NetAddr {
  union {
    hostname @0 :Text;
    ipAddr   @1 :Data;  # Could be IPv4 or IPv6
  }
  port       @2 :UInt16;
}

enum JoinFlag {
  node   @0;
  vs     @1;
  vsdock @2;
}

enum AttrOp {
    eq       @0;
    ne       @1;
    has      @2;
    excludes @3;
}

struct AttrExpr {
  key   @0 :Text;
  op    @1 :AttrOp;
  value @2 :List(Text);
}

struct Signal {
  msg @0 :Text;
  svc @1 :Text;
}

enum KeyMaterialT {
  rsaPub @0;
}

enum KeyAllowance {
  bootstrap @0;
}

struct KeyMaterial {
  id        @0  :Text;
  keyType   @1  :KeyMaterialT;
  keyAllows @2  :List(KeyAllowance);
  keyData   @3  :Data;
}

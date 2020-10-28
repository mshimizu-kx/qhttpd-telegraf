{[i;eps;p]

  / eps is the i`path successively split by slash e.g. /a/b/1234 becomes `/a/b/1234`/a/b`/a`/
  / ep is the second fully qualified component e.g. /a/b for use in sequence tracking
  ep:eps[1];
  / seq is the sequence number, which was encoded as the last component in the i`path
  seq:"J"$last "/" vs string eps[0];

  / Add the seq column to the payload, and apply casting
  p:update seq:seq,"I"$partnerId,"I"$deviceId,"P"$capturedOn,receivedOn:.z.p,"f"$speedMps,"i"$heading,"i"$ignition,"f"$lat,"f"$lon,"f"$accuracy,updateTS:.z.p,active:1b from p;

  / Inform the lmon of the latest sequence number for this ep, and get the previous recorded sequence number
  / Note: If this is a new endpoint for the sequence tracker, it will return the sequence we give it minus one for ease of logic
  seq:exec first seq from first p;
  prevseq:lmon(`.tel.seqgetandset;(ep;seq));

  / If the sequence number is not sequential vs. the previous recorded, inform the lmon
  / Note: We could do this step in the lmon, but the handlers should be user-definable at qhttpd level (at least, at present)
  if[not seq=1+prevseq;
    neg[lmon](`.qhttpd.relay2mon;
              `.tel.addAlert;
              flip `trigger_type`payload`updateTS!(enlist `seqViolation;enlist "Sequence number violation detected prev=",(string prevseq)," this=",(string seq);.z.p));
  ];

  / If the speedMps field breaches a threshold inform the lmon
  speedvios:exec {"speedMps less than 5 detected speedMps=",(string x)," for deviceID=",(string y)}'[speedMps;deviceId] from p where speedMps<5;
  if[(count speedvios)>0;
    neg[lmon](`.qhttpd.relay2mon;
              `.tel.addAlert;
              flip `trigger_type`payload`updateTS!((count speedvios)#`speedViolation;speedvios;.z.p));
  ];
  delete seq from p;

  p
}

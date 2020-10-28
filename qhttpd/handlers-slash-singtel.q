{[i;eps;p]
  update "I"$partnerId,"I"$deviceId,"P"$capturedOn,receivedOn:.z.p,"f"$speedMps,"i"$heading,"i"$ignition,"f"$lat,"f"$lon,"f"$accuracy,updateTS:.z.p,active:1b from p
  }

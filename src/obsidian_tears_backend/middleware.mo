import Random "mo:base/Random";
import Time "mo:base/Time";
import Fuzz "mo:fuzz";
import Map "mo:map/Map";
import { thash } "mo:map/Map";

import ER "lib/ext/Core";
import T "types";

module Middleware {
  let fullDay : Time.Time = 86400000000000;

  public func generateAuthToken() : async (Text) {
    let blob = await Random.blob();
    let fuzz = Fuzz.fromBlob(blob);
    return fuzz.text.randomAlphanumeric(39); // this generates a 40 character long string
  };

  public func hasValidToken(index : ER.TokenIndex, authToken : Text, registry : Map.Map<Text, T.TokenWithTimestamp>) : Bool {
    let optTokenWithTimestamp : ?T.TokenWithTimestamp = Map.get<Text, T.TokenWithTimestamp>(registry, thash, authToken);
    switch (optTokenWithTimestamp) {
      case (?tokenWithTimestamp) {
        let tokenIndex : ER.TokenIndex = tokenWithTimestamp.0;
        let timestamp : Time.Time = tokenWithTimestamp.1;
        let currentTime : Time.Time = Time.now();

        return (tokenIndex == index) and ((timestamp + fullDay) > currentTime);
      };
      case (null) return false;
    };
  };
};

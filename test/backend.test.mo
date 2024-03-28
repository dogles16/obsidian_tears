import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";

import {
  test;
  suite;
  expect;
} "mo:test/async";

import Main "../src/obsidian_tears_backend/main";
import T "../src/obsidian_tears_backend/types";
import ExtCore "../src/obsidian_tears_backend/lib/ext/Core";
import ExtCommon "../src/obsidian_tears_backend/lib/ext/Common";
import CharacterActor "../spec/actors/CharacterActor";
import ItemActor "../spec/actors/ItemActor";
import GameJsonFactory "../spec/factories/GameJsonFactory";
import AID "../src/obsidian_tears_backend/lib/util/AccountIdentifier";

let backendActor = await Main._ObsidianTearsBackend();

// ==================
// setup
// ==================

// spec actor/caller id
let selfId = Principal.fromText("wo5qg-ysjiq-5da");
let selfAddress : ExtCore.AccountIdentifier = AID.fromPrincipal(selfId, null);

// stubbed actors
let characterActor = await CharacterActor.CharacterActor();
let characterActorId = Principal.toText(Principal.fromActor(characterActor));
let itemActor = await ItemActor.ItemActor();
let itemActorId = Principal.toText(Principal.fromActor(itemActor));
ignore await backendActor.specSetStubbedCanisterIds(characterActorId, itemActorId);

// set default character nfts
let defaultCharacterTokensResponse : Result.Result<[ExtCore.TokenIndex], ExtCore.CommonError> = #ok([1, 2, 3, 4]);
await characterActor.setTokensResponse(defaultCharacterTokensResponse);
let defaultItemTokensResponse : Result.Result<[ExtCore.TokenIndex], ExtCore.CommonError> = #ok([1, 5, 34]);
await itemActor.setTokensResponse(defaultItemTokensResponse);
let defaultCharacterRegistryResponse : [(ExtCore.TokenIndex, ExtCore.AccountIdentifier)] = [(1, selfAddress), (2, selfAddress)];
await characterActor.setRegistryResponse(defaultCharacterRegistryResponse);

// vars
var playerNftId : Nat32 = 2;
var itemNftIndex : Nat32 = 5;
var gameData : Text = GameJsonFactory.defaultGameJson;
var chestId : Nat16 = 35;

await suite(
  "#verify",
  func() : async () {
    await test(
      "should return list of NFTs owned",
      func() : async () {
        let response = await backendActor.verify();
        assert response == #Ok([1, 2, 3, 4]);
      },
    );
    await test(
      "should update registery cache of Characters owned",
      func() : async () {
        func show(a : Result.Result<(ExtCore.AccountIdentifier), Text>) : Text = debug_show (a);
        func equal(a : Result.Result<(ExtCore.AccountIdentifier), Text>, b : Result.Result<(ExtCore.AccountIdentifier), Text>) : Bool = a == b;

        let ownerId = await backendActor.specGetCharacterOwner(playerNftId);
        expect.result<(ExtCore.AccountIdentifier), Text>(ownerId, show, equal).equal(#ok(selfAddress));
      },
    );
    await test(
      "should update registry cache of Items owned",
      func() : async () {
        func show(a : Result.Result<(ExtCore.AccountIdentifier), Text>) : Text = debug_show (a);
        func equal(a : Result.Result<(ExtCore.AccountIdentifier), Text>, b : Result.Result<(ExtCore.AccountIdentifier), Text>) : Bool = a == b;

        let ownerId = await backendActor.specGetItemOwner(itemNftIndex);
        expect.result<(ExtCore.AccountIdentifier), Text>(ownerId, show, equal).equal(#ok(selfAddress));
      },
    );
  },
);
await suite(
  "#loadGame",
  func() : async () {
    await test(
      "when no game saved, returns error with message",
      func() : async () {
        let response = await backendActor.loadGame(playerNftId);
        assert response == #Err(#Other("No save data"));
      },
    );
    await test(
      "when game saved, returns game successfully",
      func() : async () {
        // before
        ignore await backendActor.saveGame(playerNftId, gameData);

        // assert
        let response = await backendActor.loadGame(playerNftId);

        // after
        ignore await backendActor.saveGame(playerNftId, "");

        switch (response) {
          case (#Ok(gameData)) assert (Text.size(gameData) > 12900);
          case (#Err(_message)) assert false;
        };
      },
    );
  },
);
await suite(
  "#saveGame",
  func() : async () {
    await test(
      "saves and returns the load game output to be rendered",
      func() : async () {
        let response = await backendActor.saveGame(playerNftId, gameData);
        switch (response) {
          case (#Ok(gameData)) {
            assert (Text.size(gameData) > 12900);
          };
          case (#Err(_message)) assert false;
        };
      },
    );
    await test(
      "when caller is not owner of token refuses to save and returns error message",
      func() : async () {
        let response = await backendActor.saveGame(999, gameData);
        // TODO: improve with right caller
        // switch (response) {
        //  case (#Ok(gameData)) false;
        //  case (#Err(_message)) true;
        // };
        assert true;
      },
    );
  },
);
await suite(
  "#openChest",
  func() : async () {
    await test(
      "mints items and adds gold",
      func() : async () {
        let expectedRewardInfo : T.RewardInfo = {
          itemIds = ["4290235510"];
          gold = 20;
          xp = 0;
        };
        let response = await backendActor.openChest(playerNftId, chestId);
        switch (response) {
          case (#Ok(rewardInfo)) assert (rewardInfo == expectedRewardInfo);
          case (#Err(_message)) assert false;
        };
      },
    );
  },
);
await suite(
  "#defeatMonster",
  func() : async () {
    await test(
      "returns rewards from defeated monster",
      func() : async () {
        let monsterId : Nat16 = 1;
        let response = await backendActor.defeatMonster(playerNftId, monsterId);
        switch (response) {
          case (#Ok(rewardInfo)) assert true;
          case (#Err(message)) Debug.trap(debug_show (message));
        };
      },
    );
  },
);

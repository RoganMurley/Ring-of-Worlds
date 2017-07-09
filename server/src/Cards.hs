module Cards where

import Model
import Player (WhichPlayer(..), other)
import Util (shuffle, times)


-- Striker
dagger :: Card
dagger =
  Card
    "Dagger"
    "Hurt for 7"
    "striker/dagger.svg"
    "dagger.wav"
    $ \p -> hurt 7 (other p)


fireball :: Card
fireball =
  Card
    "Fireball"
    "Hurt for 5 for each card to the right"
    "striker/fireball.svg"
    "fireball.wav"
    $ \p m -> hurt (5 * (length . getStack $ m)) (other p) m


offering :: Card
offering =
  Card
    "Offering"
    "Hurt yourself for 8, then draw 2"
    "striker/offering.svg"
    "offering.wav"
    $ \p -> (times 2 (drawCard p)) . (hurt 8 p)


confound :: Card
confound =
  Card
    "Confound"
    "Shuffle the order of cards to the right"
    "striker/confound.svg"
    "confound.wav"
    $ \_ m -> modStack (shuffle (getGen m)) m


-- Breaker
hammer :: Card
hammer =
  Card
    "Hammer"
    "Hurt for 8"
    "breaker/hammer.svg"
    "hammer.wav"
    $ \p -> hurt 8 (other p)


lightning :: Card
lightning =
  Card
    "Lightning"
    "Hurt for 4 for each card to the right"
    "breaker/lightning.svg"
    "lightning.wav"
    $ \p m -> hurt (4 * (length . getStack $ m)) (other p) m


hubris :: Card
hubris =
  Card
    "Hubris"
    "Remove all cards to the right"
    "breaker/hubris.svg"
    "hubris.wav"
    $ \_ -> setStack []


exile :: Card
exile =
  Card
    "Exile"
    "Remove all other copies of card to the right, wherever they are"
    "breaker/exile.svg"
    "echo.wav"
    $ withStackHead eff
  where
    eff :: StackCard -> CardEff
    eff stackCard@(StackCard _ card) _ =
        (both (\p -> modDeck p $ filter (/= card)))
      . (both (\p -> modHand p $ filter (/= card)))
      . (modStack ((:) stackCard))
      . (modStack (filter (\(StackCard _ c) -> c /= card)))


-- Balancer
katana :: Card
katana =
  Card
    "Katana"
    "Hurt for 9"
    "balancer/katana.svg"
    "axe.mp3"
    $ \p -> hurt 9 (other p)


curse :: Card
curse =
  Card
    "Curse"
    "Hurt weakest player for 15"
    "balancer/curse.svg"
    "frostbite.mp3"
    eff
  where
    eff :: CardEff
    eff _ m
      | getLife PlayerA m < getLife PlayerB m =
        hurt dmg PlayerA $ m
      | getLife PlayerA m > getLife PlayerB m =
        hurt dmg PlayerB $ m
      | otherwise =
        (hurt dmg PlayerA) . (hurt dmg PlayerB) $ m
    dmg = 15


bless :: Card
bless =
  Card
    "Bless"
    "Heal weakest player for 15"
    "balancer/bless.svg"
    "oath.wav"
    eff
  where
    eff :: CardEff
    eff _ m
      | getLife PlayerA m < getLife PlayerB m =
        heal mag PlayerA $ m
      | getLife PlayerA m > getLife PlayerB m =
        heal mag PlayerB $ m
      | otherwise =
        (heal mag PlayerA) . (heal mag PlayerB) $ m
    mag = 15


balance :: Card
balance =
  Card
    "Balance"
    "Next card changes owner to weakest player"
    "balancer/balance.svg"
    "feint.wav"
    $ \_ m -> modStackHead (eff (getLife PlayerA m, getLife PlayerB m)) m
  where
    eff :: (Life, Life) -> StackCard -> StackCard
    eff (lifePA, lifePB) (StackCard which card) = StackCard weakest card
      where
        weakest :: WhichPlayer
        weakest
          | lifePA < lifePB = PlayerA
          | lifePB < lifePA = PlayerB
          | otherwise       = which


-- Drinker
scythe :: Card
scythe =
  Card
    "Scythe"
    "Lifesteal for 6"
    "drinker/scythe.svg"
    "bite.wav"
    $ \p -> lifesteal 6 (other p)


bloodsucker :: Card
bloodsucker =
  Card
  "Bloodsucker"
  "Lifesteal for 3 for each card to the right"
  "drinker/bloodsucker.svg"
  "succubus.wav"
  $ \p m -> lifesteal (3 * (length . getStack $ m)) (other p) m


serpent :: Card
serpent =
  Card
    "Serpent"
    "Add 2 (BAD APPLE: Hurt yourself for 8) to their hand"
    "drinker/serpent.svg"
    "siren.wav"
    $ \p -> modHand (other p) (times 2 ((:) badApple))


badApple :: Card
badApple =
  Card
    "Bad Apple"
    "Hurt yourself for 8"
    "drinker/bad-apple.svg"
    "song.wav"
    $ hurt 8


reversal :: Card
reversal =
  Card
    "Reversal"
    "Reverse the order of cards to the right"
    "drinker/reversal.svg"
    "reversal.wav"
    $ \_ -> modStack reverse


-- Watcher
staff :: Card
staff =
  Card
    "Staff"
    "Hurt for 5"
    "watcher/staff.svg"
    "staff.wav"
    $ \p -> hurt 5 (other p)


overburden :: Card
overburden =
  Card
    "Overburden"
    "Hurt for 3 for each card in their hand"
    "watcher/overburden.svg"
    "envy.wav"
    $ \p m -> hurt (3 * (length . (getHand (other p)) $ m)) (other p) m


mindhack :: Card
mindhack =
  Card
    "Mindhack"
    "Obscure their hand"
    "watcher/mindhack.svg"
    "mindhack.wav"
    $ \p -> modHand (other p) (fmap obs)
  where
    obs :: Card -> Card
    obs card
      | card == (obscured card) = card
      | otherwise = obscured card


obscured :: Card -> Card
obscured c =
  Card
    "???"
    "An obscured card"
    "watcher/obscured.svg"
    "resolve.wav"
    $ \p -> modStack $ (:) (StackCard p c)


prophecy :: Card
prophecy =
  Card
    "Prophecy"
    "Bounce all cards to the right to hand"
    "watcher/prophecy.svg"
    "precognition.wav"
    $ \_ -> (bounceAll PlayerA) . (bounceAll PlayerB)


-- Shielder
sword :: Card
sword =
  Card
    "Sword"
    "Hurt for 11"
    "shielder/sword.svg"
    "dagger.wav"
    $ \p -> hurt 11 (other p)


soulburn :: Card
soulburn =
  Card
    "Soulburn"
    "Hurt for 25%"
    "shielder/soulburn.svg"
    "envy.wav"
    $ \p m -> hurt (quot (getLife (other p) m) 4) (other p) m


potion :: Card
potion =
  Card
    "Potion"
    "Heal for 10"
    "shielder/potion.svg"
    "potion.wav"
    $ heal 10


reflect :: Card
reflect =
  Card
    "Reflect"
    "All cards to the right change owner"
    "shielder/reflect.svg"
    "reflect.wav"
    $ \_ -> modStackAll changeOwner


-- Bouncer
boomerang :: Card
boomerang =
  Card
    "Boomerang"
    "Hurt for 3, bounce this card to hand"
    "bouncer/boomerang.svg"
    "boomerang.wav"
    $ \p -> (modHand p ((:) boomerang)) . (hurt 3 (other p))


overwhelm :: Card
overwhelm =
  Card
    "Overwhelm"
    "Hurt for 3 for each card in your hand"
    "bouncer/overwhelm.svg"
    "superego.wav"
    $ \p m -> hurt (3 * (length . (getHand p) $ m)) (other p) m


return' :: Card
return' =
  Card
    "Return"
    "Next card bounces to hand after activating"
    "bouncer/return.svg"
    "echo.wav"
    eff
  where
    eff :: CardEff
    eff _ = modStackHead
      (\(StackCard o c@(Card n d i s e)) ->
        StackCard o (Card n d i s (\w -> (modHand w ((:) c)) . (e w))))


feint :: Card
feint =
  Card
    "Feint"
    "Bounce all of your cards to the right to hand"
    "bouncer/feint.svg"
    "feint.wav"
    bounceAll


-- Collector
runeblade :: Card
runeblade =
  Card
    "runeblade"
    "Hurt for 7"
    "collector/runeblade.svg"
    "dagger.wav"
    $ \p -> hurt 7 (other p)


surge :: Card
surge =
  Card
    "Surge"
    "Hurt for 5 for each of your cards to the right"
    "collector/surge.svg"
    "fireball.wav"
    eff
  where
    eff :: CardEff
    eff p m =
      hurt
        (5 * (length . (filter (\(StackCard o _) -> o == p)) . getStack $ m))
          (other p) m


hoard :: Card
hoard =
  Card
    "Hoard"
    "Add 10 copies of next card to owner's deck"
    "collector/hoard.svg"
    "feint.wav"
    $ withStackHead eff
  where
    eff :: StackCard -> CardEff
    eff (StackCard o card) =
      \_ m ->
          (modDeck o (shuffle (getGen m)))
        . (modDeck o ((++) (replicate 10 card)))
        $ m


transmute :: Card
transmute =
  Card
    "Transmute"
    "Change next card to (GOLD: draw 2)"
    "collector/transmute.svg"
    "feint.wav"
    $ \_ -> modStackHead (\(StackCard w _) -> StackCard w gold)


gold :: Card
gold =
  Card
    "Gold"
    "Draw 2"
    "collector/gold.svg"
    "feint.wav"
    $ \p -> (drawCard p) . (drawCard p)


-- Augmenter
fist :: Card
fist =
  Card
    "Fist"
    "Hurt for 1"
    "augmenter/fist.svg"
    "feint.wav"
    $ \p -> hurt 1 (other p)


supercharge :: Card
supercharge =
  Card
    "Echo"
    "Next card activates twice"
    "augmenter/echo.svg"
    "echo.wav"
    eff
  where
    eff :: CardEff
    eff _ = modStackHead
      (\(StackCard which (Card name desc pic sfx e)) ->
        StackCard which (Card name desc pic sfx (\w -> (e w) . (e w))))


echo :: Card
echo =
  Card
    "Echo"
    "Next card activates twice"
    "augmenter/echo.svg"
    "echo.wav"
    eff
  where
    eff :: CardEff
    eff _ = modStackHead
      (\(StackCard which (Card name desc pic sfx e)) ->
        StackCard which (Card name desc pic sfx (\w -> (e w) . (e w))))


-- Potential future cards
soulheal :: Card
soulheal =
  Card
    "Soulheal"
    "Heal for 50%"
    ""
    "resolve.wav"
    $ \p m -> heal (quot (getLife p m) 2) p m



treasure :: Card
treasure =
  Card
    "Treasure"
    "Both draw 2"
    ""
    "gold.wav"
    $ \_ -> times 2 (both drawCard)

module Klar.Avatar.Entry exposing (Entry, entry, image, name, withImage)

{-| One entry of an avatar group, opaque so that it can grow (a status, an icon)
without breaking an application. `Klar.Avatar` re-exports the type and the
builders; components of Klar that draw people (`Klar.ApprovalFlow`) read it here.
-}


type Entry
    = Entry { name : String, image : Maybe String }


entry : String -> Entry
entry value =
    Entry { name = value, image = Nothing }


withImage : Maybe String -> Entry -> Entry
withImage url (Entry e) =
    Entry { e | image = url }


name : Entry -> String
name (Entry e) =
    e.name


image : Entry -> Maybe String
image (Entry e) =
    e.image

module Page.Applications.Catalog exposing (Page(..), all, description, fromSlug, icon, slug, title)

{-| The registry for complete application patterns. Add a page here, implement its
view in Page.Applications, and it appears in navigation and command search.
-}

import Klar.Icon as Icon exposing (Icon)


type Page
    = SignIn
    | SignUp
    | ForgotPassword
    | ResetPassword
    | Connections
    | GitHub
    | Google
    | AiProviders
    | Classification
    | Processes
    | Calendar


all : List Page
all =
    [ Calendar, SignIn, SignUp, ForgotPassword, ResetPassword, Connections, GitHub, Google, AiProviders, Classification, Processes ]


slug : Page -> String
slug page =
    case page of
        Calendar ->
            "google-calendar"

        SignIn ->
            "sign-in"

        SignUp ->
            "sign-up"

        ForgotPassword ->
            "forgot-password"

        ResetPassword ->
            "reset-password"

        Connections ->
            "connections"

        GitHub ->
            "github"

        Google ->
            "google-workspace"

        AiProviders ->
            "ai-providers"

        Classification ->
            "jev-classification"

        Processes ->
            "process-studio"


fromSlug : String -> Maybe Page
fromSlug value =
    List.filter (slug >> (==) value) all |> List.head


title : Page -> String
title page =
    case page of
        Calendar ->
            "Google Calendar demo"

        SignIn ->
            "Sign in"

        SignUp ->
            "Create account"

        ForgotPassword ->
            "Forgot password"

        ResetPassword ->
            "Reset password"

        Connections ->
            "Connected apps"

        GitHub ->
            "GitHub connection"

        Google ->
            "Google Workspace"

        AiProviders ->
            "AI providers & keys"

        Classification ->
            "JEV classification"

        Processes ->
            "Process studio"


description : Page -> String
description page =
    case page of
        Calendar ->
            "A complete Google Calendar-style application with day, week, month and agenda views, shared calendars, invitations and recurring events."

        SignIn ->
            "A welcoming entry point with Google, Microsoft and email sign-in."

        SignUp ->
            "Create a workspace account, validate details and verify an email address."

        ForgotPassword ->
            "Request a recovery email without revealing whether an account exists."

        ResetPassword ->
            "Choose a new password and handle an expired recovery link."

        Connections ->
            "Give your assistant access to the tools your team already uses."

        GitHub ->
            "Choose repositories and review access before connecting your workspace."

        Google ->
            "Connect selected Drive files and calendars for background imports."

        AiProviders ->
            "Manage credentials and choose the providers available to your assistant."

        Classification ->
            "Follow documents from the queue to a classification, with a person in control."

        Processes ->
            "Build and run visual AI/human workflows with branches, bounded revisions and observable state."


icon : Page -> Icon
icon page =
    case page of
        Calendar ->
            Icon.calendar

        SignIn ->
            Icon.logIn

        SignUp ->
            Icon.userPlus

        ForgotPassword ->
            Icon.mail

        ResetPassword ->
            Icon.lock

        Connections ->
            Icon.link

        GitHub ->
            Icon.gitBranch

        Google ->
            Icon.cloud

        AiProviders ->
            Icon.key

        Classification ->
            Icon.layers

        Processes ->
            Icon.gitBranch

module Page.Gallery.Markdown.Sample exposing (answer, document, note, unsafe)

{-| The texts of the Markdown page: a long document with every feature, the answer
that is revealed a few characters at a time, a text that tries to do harm, and the
note that the editors start with.
-}


{-| Every feature, in a document about a delivery.
-}
document : String
document =
    """# Delivery plan for the Oslo warehouse

This document shows what Klar.Markdown understands. It is about a
delivery, because that is something every warehouse knows. Text can be **strong**,
*emphasized*, ***both***, ~~struck through~~ and `inline code`; a line can end with
two spaces
to break the line.

## Summary

Seven orders leave on *Monday*, **three** of them for customers in Bergen. Ask
[the warehouse](mailto:warehouse@example.com) or read [the schedule](https://example.com/schedule "Open the schedule")
first. A plain address such as https://example.com/orders/17 becomes a link, and so
does <https://example.com/help>.

### Items in the shipment

- Chairs, 24 of them
- Tables
  - Large tables, **fragile**
  - Small tables
    - Side tables
- Lamps

Numbered lists keep their number:

3. Pack the chairs
4. Seal the boxes
5. Hand them to the driver

A loose list has room between the items:

- The first item has a paragraph of its own.

- The second has two paragraphs.

  Here is the second one.

#### Checklist

- [x] Count the chairs
- [x] Order labels
- [ ] Book the truck
- [ ] Tell the customer

## Notes

> The driver leaves at 07:30.
> Doors close at 07:15.
>
> > A quote inside a quote: keep the pallets dry.
>
> - and a list inside a quote

A rule between two parts of the text:

---

### Code

Code is not interpreted, and a long line scrolls inside its own box:

```elm
total : List Order -> Int
total orders =
    List.sum (List.map .quantity orders) + extraCostForRemoteLocationsInTheNorthOfTheCountry orders
```

```
plain text in a block, without a language
```

    four spaces make a block of code as well

### Table

| Item          | Count | Unit price | Note                       |
|:--------------|------:|-----------:|:--------------------------:|
| Chair         |    24 |      40.00 | stackable                  |
| Table, large  |     3 |     120.00 | **fragile**                |
| Table, small  |     8 |      65.00 | `SKU-0042`                 |
| Lamp          |    12 |      18.50 | ships in a separate carton |

### Links and images

[A relative link](/orders/17), a link to an address with a title (hover it), and an image:
![A stack of chairs](chair.png "Chairs") is not loaded unless the page asks for
it. Only these addresses are links: javascript:alert(1) is text, and so is
[this one](javascript:alert(1)).

### Other things

An escaped \\*star\\* is text. Norwegian letters, æ ø å, and emoji 📦 are text too.
HTML is text: <b>not bold</b>.

## Features

Everything above is the whole list, and the parser keeps going when the text is
unfinished.
"""


{-| An answer of the kind a language model writes, to be revealed slowly.
-}
answer : String
answer =
    """## Why the order is late

The truck left **two hours late**, because the *loading dock* was full. You can follow
the shipment on [the tracking page](https://example.com/track/4711).

Three things happened:

1. The pallets arrived at 06:10
2. The label printer was out of paper
3. The driver waited for a signature

| Step | Planned | Actual |
|------|--------:|-------:|
| Loading | 06:30 | 07:05 |
| Departure | 07:00 | 09:10 |

To check the status yourself:

```sh
curl https://example.com/api/orders/4711
```

Sorry for the trouble 📦 — it will arrive on **Tuesday**.
"""


{-| Text that tries to do harm. Every line is shown as text.
-}
unsafe : String
unsafe =
    """<script>alert("script")</script>

<img src=x onerror=alert("image")>

[Click me](javascript:alert("link"))

[A page of my own](data:text/html,<h1>mine</h1>)

![A tracking pixel](https://tracker.example/pixel.gif?reader=42)

[A good link](https://example.com)
"""


{-| The text of the editors.
-}
note : String
note =
    """# Packing slip

Pack the **chairs** first, then the tables.

- [ ] Count the boxes
- [ ] Check the labels

See [the schedule](https://example.com/schedule).
"""

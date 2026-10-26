// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import App from "./App";

describe("ReStock sign-in screen", () => {
  beforeEach(() => {
    cleanup();
    sessionStorage.clear();
  });

  it("shows the sign-in form when no session token exists", () => {
    render(<App />);

    expect(screen.getByRole("heading", { name: "Welcome to ReStock" })).toBeInTheDocument();
    expect(screen.getByLabelText("Email address")).toBeInTheDocument();
    expect(screen.getByLabelText("Password")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign in" })).toBeInTheDocument();
  });
});
